import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/models/admin_notification_model.dart';
import '../../../core/utils/time_helper.dart';
import '../services/admin_notification_service.dart';

class AdminAlertNotifier extends Notifier<void> {
  final Set<String> _notifiedKeys = {};
  Timer? _timer;

  @override
  void build() {
    _startTimer();
    ref.onDispose(() => _timer?.cancel());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkReminders();
    });
  }

  void _checkReminders() {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    final sessionsAsync = ref.read(sessionsStreamProvider);
    final releasedAsync = ref.read(releasedSessionsProvider(todayStr));

    final allSessions = sessionsAsync.value ?? [];
    final releasedSessions = releasedAsync.value ?? [];
    final releasedIds = releasedSessions.map((r) => r['sessionId']).toSet();

    for (var session in allSessions.where((s) => s.isActive)) {
      if (releasedIds.contains(session.id)) continue;

      final startDt = TimeHelper.parseSessionTime(session.startTime, now);
      if (startDt == null || startDt.isBefore(now)) continue;

      final minutesUntil = startDt.difference(now).inMinutes;

      for (var threshold in [60, 30, 10]) {
        final key = 'reminder:$todayStr:${session.id}:$threshold';
        if (_notifiedKeys.contains(key)) continue;

        if (minutesUntil <= threshold) {
          _notifiedKeys.add(key);
          _createNotification(
            title: 'Session Reminder',
            body: '${session.name} starts in ~$minutesUntil minutes. Menu not released.',
            type: AdminNotificationType.reminder,
            sessionId: session.id,
            actionType: 'release',
          );
          break; 
        }
      }
    }

    // --- NEW: Check for sessions ending soon (to prepare for carry over) ---
    for (var rs in releasedSessions) {
      final sId = rs['sessionId'] as String;
      final key = 'ending:$todayStr:$sId';
      if (_notifiedKeys.contains(key)) continue;

      final endDt = TimeHelper.parseSessionTime(rs['endTime'] ?? '', now);
      if (endDt == null) continue;

      final minutesUntilEnd = endDt.difference(now).inMinutes;

      // Notify if ending in <= 10 minutes but not already ended
      if (minutesUntilEnd <= 10 && minutesUntilEnd > 0) {
        _notifiedKeys.add(key);
        _createNotification(
          title: 'Session Ending Soon',
          body: '${rs['sessionNameSnapshot'] ?? rs['sessionName'] ?? 'Session'} ends in ~$minutesUntilEnd minutes. Prepare for carry over.',
          type: AdminNotificationType.reminder,
          sessionId: sId,
        );
      }
    }

    // --- NEW: Check for leftovers periodically ---
    _checkLeftovers(todayStr, releasedSessions, now);
  }

  void _checkLeftovers(String todayStr, List<Map<String, dynamic>> releasedSessions, DateTime now) async {
    // 1. Find the most recently ended session
    Map<String, dynamic>? mostRecentEnded;
    DateTime? latestEndTime;

    for (var rs in releasedSessions) {
      final endDt = TimeHelper.parseSessionTime(rs['endTime'] ?? '', now);
      if (endDt != null && endDt.isBefore(now)) {
        if (latestEndTime == null || endDt.isAfter(latestEndTime)) {
          latestEndTime = endDt;
          mostRecentEnded = rs;
        }
      }
    }

    if (mostRecentEnded == null) return;

    final rs = mostRecentEnded;
    final sId = rs['sessionId'];
    final key = 'leftover:$todayStr:$sId';
    
    // 2. Mark any OLDER carry_over notifications for today as read
    try {
      final notifications = ref.read(adminNotificationsStreamProvider).valueOrNull ?? [];
      for (var n in notifications) {
        if (!n.isRead && n.actionType == 'carry_over' && n.sessionId != sId) {
          // Verify it's from today (optional but safer)
          final nDate = DateFormat('yyyy-MM-dd').format(n.timestamp);
          if (nDate == todayStr) {
            ref.read(adminNotificationServiceProvider).markAsRead(n.id);
          }
        }
      }
    } catch (_) {}

    // If we've already notified for this specific session's leftovers, skip
    if (_notifiedKeys.contains(key)) return;

    // Session ended. Check items for leftovers.
    try {
      final itemsSnap = await ref
          .read(firestoreServiceProvider)
          .getSessionItemsStream('default', todayStr, sId)
          .first;
          
      bool hasNormalLeftovers = false;
      int normalCount = 0;
      bool hasPreReadyLeftovers = false;
      int preReadyCount = 0;
      
      for (var doc in itemsSnap.docs) {
        final data = doc.data();
        final stock = data['remainingStock'] ?? data['availableStock'] ?? 0;
        final isPreReady = data['isPreReady'] ?? false;
        
        if (stock > 0) {
          if (isPreReady) {
            hasPreReadyLeftovers = true;
            preReadyCount++;
          } else {
            hasNormalLeftovers = true;
            normalCount++;
          }
        }
      }

      // --- Handle Pre-Ready Automatically ---
      if (hasPreReadyLeftovers) {
        // Find next released session to move into
        final nextSession = releasedSessions.firstWhere(
          (s) {
            if (s['sessionId'] == sId) return false;
            final start = TimeHelper.parseSessionTime(s['startTime'] ?? '', now);
            // Use latestEndTime since it's the end of the session we are carrying FROM
            return start != null && start.isAfter(latestEndTime!);
          },
          orElse: () => {},
        );

        if (nextSession.isNotEmpty) {
          final toId = nextSession['sessionId'];
          final toName = nextSession['sessionNameSnapshot'] ?? nextSession['sessionName'] ?? 'Next Session';
          
          await ref.read(firestoreServiceProvider).autoCarryOverPreReadyItems(
            canteenId: 'default',
            date: todayStr,
            fromSessionId: sId,
            toSessionId: toId,
          );

          _createNotification(
            title: 'Auto Carry Over',
            body: 'Moved $preReadyCount ready-made items from ${rs['sessionNameSnapshot'] ?? 'ended session'} to $toName.',
            type: AdminNotificationType.success,
            sessionId: toId,
          );
        }
      }

      if (hasNormalLeftovers) {
        _notifiedKeys.add(key);
        _createNotification(
          title: 'Carry Over Needed',
          body: '${rs['sessionNameSnapshot'] ?? rs['sessionName'] ?? 'Session'} has $normalCount items remaining. Click to carry over.',
          type: AdminNotificationType.alert,
          sessionId: sId,
          actionType: 'carry_over',
          metadata: {
            'sessionName': rs['sessionNameSnapshot'] ?? rs['sessionName'] ?? 'Session',
            'itemCount': normalCount,
          }
        );
      } else {
        // No normal leftovers, still mark as notified to avoid repeated queries
        _notifiedKeys.add(key);
      }
    } catch (e) {
      // Silently fail on network/permission issues during background check
    }
  }

  Future<void> _createNotification({
    required String title,
    required String body,
    required AdminNotificationType type,
    String? sessionId,
    String? actionType,
    Map<String, dynamic>? metadata,
  }) async {
    final notification = AdminNotification(
      id: '', // Firestore will generate
      title: title,
      body: body,
      type: type,
      timestamp: DateTime.now(),
      sessionId: sessionId,
      actionType: actionType,
      metadata: metadata,
    );

    await ref.read(adminNotificationServiceProvider).addNotification(notification);
  }

  // Helper called from dashboard to log manual actions or logic results
  Future<void> logCarryOver({
    required String fromSession,
    required String toSession,
    required bool success,
    required int itemCount,
    String? sessionId,
  }) async {
    await _createNotification(
      title: success ? 'Carry Over Success' : 'Carry Over Failed',
      body: success 
          ? '$itemCount items successfully carried over from $fromSession to $toSession.'
          : 'Failed to carry over $itemCount items from $fromSession to $toSession.',
      type: success ? AdminNotificationType.success : AdminNotificationType.alert,
      sessionId: sessionId,
    );
  }

  Future<void> logMenuReleasedReminded({
    required String sessionName,
    required int minutesLeft,
    required String sessionId,
    required int threshold,
  }) async {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = 'reminder:$todayStr:$sessionId:$threshold';
    
    // Don't double-log if already in notifiedKeys
    if (_notifiedKeys.contains(key)) return;
    _notifiedKeys.add(key);

    await _createNotification(
      title: 'Session Reminder ($threshold min)',
      body: '$sessionName starts in ~$minutesLeft minutes. Please release the menu.',
      type: AdminNotificationType.reminder,
      sessionId: sessionId,
      actionType: 'release',
    );
  }

  Future<void> logMenuReleased({
    required String sessionName,
    String? sessionId,
  }) async {
    await _createNotification(
      title: 'Menu Released',
      body: 'The menu for $sessionName has been released successfully.',
      type: AdminNotificationType.success,
      sessionId: sessionId,
    );
  }
}

final adminAlertProvider = NotifierProvider<AdminAlertNotifier, void>(() {
  return AdminAlertNotifier();
});
