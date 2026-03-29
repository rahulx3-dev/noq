import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/app_notification_banner.dart';
import 'student_orders_provider.dart';
import '../services/student_notification_service.dart';
import '../../../core/models/student_models.dart';
import '../../../core/utils/time_helper.dart';

class OrderAlert {
  final String title;
  final String body;
  final String? token;
  final AlertType type;
  final String? orderId;

  OrderAlert({
    required this.title,
    required this.body,
    this.token,
    required this.type,
    this.orderId,
  });
}

class StudentAlertNotifier extends Notifier<OrderAlert?> {
  final Set<String> _notifiedKeys = {};
  Timer? _reminderTimer;

  @override
  OrderAlert? build() {
    // Start a timer for reminders
    _startReminderTimer();
    return null;
  }

  void _startReminderTimer() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkReminders();
    });
  }

  void _checkReminders() {
    final activeOrders = ref.read(studentActiveOrdersProvider);
    final now = DateTime.now();

    for (var order in activeOrders) {
      final orderId = order['orderId'] as String?;
      final token = order['tokenNumber']?.toString();
      final startTimeStr = order['slotStartTime'] as String?;
      final status = order['orderStatus'] as String?;

      if (orderId == null ||
          startTimeStr == null ||
          (status != 'pending' && status != 'accepted')) {
        continue;
      }

      final startTime = TimeHelper.parseSessionTime(startTimeStr, now);
      if (startTime == null) continue;

      final diffInMinutes = startTime.difference(now).inMinutes;
      final checkpoints = [60, 30, 10, 5];

      for (var mins in checkpoints) {
        final key = '$orderId:remind:$mins';
        if (diffInMinutes <= mins &&
            diffInMinutes > 0 &&
            !_notifiedKeys.contains(key)) {
          _notifiedKeys.add(key);
          showAlert(
            OrderAlert(
              title: 'Pickup Reminder',
              body: 'in $mins mins',
              token: token,
              type: AlertType.reminder,
              orderId: orderId,
            ),
          );
          return; // Only show one reminder at a time
        }
      }
    }
  }

  void processMenuUpdates(StudentDailyMenu? previous, StudentDailyMenu? next) {
    if (next == null) return;

    // 1. Menu Released Check
    // Only notify if we transition from unreleased -> released while the app is active
    if (previous != null) {
      final previouslyReleased = previous.isReleased;
      if (next.isReleased && !previouslyReleased) {
        showAlert(
          OrderAlert(
            title: 'Menu Live!',
            body: 'Today\'s menu is now available.',
            type: AlertType.menu,
          ),
        );
        return; // Skip other checks if menu just released
      }
    }

    if (!next.isReleased) return;

    // 2. Item Added & Stock Replenished Check
    for (var session in next.sessions) {
      final prevSession = previous?.sessions.firstWhere(
        (s) => s.sessionId == session.sessionId,
        orElse: () => StudentMenuSession(
          sessionId: session.sessionId,
          sessionNameSnapshot: session.sessionNameSnapshot,
          startTime: session.startTime,
          endTime: session.endTime,
          items: [],
          slots: [],
        ),
      );

      for (var item in session.items) {
        if (!item.isAvailableSnapshot && item.remainingStock <= 0) continue;

        final prevItem = prevSession?.items.firstWhere(
          (i) => i.itemId == item.itemId,
          orElse: () => StudentMenuItem(
            itemId: item.itemId,
            categoryIdSnapshot: item.categoryIdSnapshot,
            nameSnapshot: item.nameSnapshot,
            descriptionSnapshot: item.descriptionSnapshot,
            priceSnapshot: item.priceSnapshot,
            imageUrlSnapshot: item.imageUrlSnapshot,
            isAvailableSnapshot: false,
            remainingStock: 0,
            sessionId: session.sessionId,
            sessionNameSnapshot: session.sessionNameSnapshot,
          ),
        );

        // Item Added (Newly available)
        final endDt = TimeHelper.parseSessionTime(session.endTime, DateTime.now());
        final isPast = endDt != null && DateTime.now().isAfter(endDt);

        if (!isPast &&
            item.isAvailableSnapshot &&
            !(prevItem?.isAvailableSnapshot ?? false)) {
          final key = 'menu:added:${item.itemId}';
          if (!_notifiedKeys.contains(key)) {
            _notifiedKeys.add(key);
            if (previous != null) {
              showAlert(
                OrderAlert(
                  title: 'New Item Added',
                  body:
                      '${item.nameSnapshot} added to ${session.sessionNameSnapshot}',
                  type: AlertType.menu,
                ),
              );
            }
          }
        }
        // Stock Replenished (Was out of stock, now has stock)
        else if (!isPast &&
            item.remainingStock > 0 &&
            (prevItem?.remainingStock ?? 0) <= 0) {
          final key = 'menu:stock:${item.itemId}:${item.remainingStock}';
          if (!_notifiedKeys.contains(key)) {
            _notifiedKeys.add(key);
            if (previous != null) {
              showAlert(
                OrderAlert(
                  title: 'Stock Replenished',
                  body: '${item.nameSnapshot} is back in stock!',
                  type: AlertType.stock,
                ),
              );
            }
          }
        }
      }
    }
  }

  void processOrderUpdates(
    List<Map<String, dynamic>>? previous,
    List<Map<String, dynamic>> next,
  ) {
    if (next.isEmpty) return;

    final prevIds = previous?.map((o) => o['orderId'] as String).toSet() ?? {};

    for (var order in next) {
      final orderId = order['orderId'] as String?;
      final token = order['tokenNumber']?.toString();
      final status = order['orderStatus'] as String?;
      final items = order['items'] as List<dynamic>? ?? [];
      final createdAt = (order['createdAt'] as Timestamp?)?.toDate();

      if (orderId == null) continue;

      final isRecent = createdAt != null &&
          DateTime.now().difference(createdAt).inMinutes < 10;
      
      // Determine if this specific update is occurring 'now' for banners
      // We check if the order was updated in the last 60 seconds
      final updatedAt = (order['updatedAt'] as Timestamp?)?.toDate();
      final isFreshUpdate = updatedAt != null && 
          DateTime.now().difference(updatedAt).inSeconds < 60;

      // 1. New Order Placed Check
      if (!prevIds.contains(orderId)) {
        if (isRecent) {
          showAlert(
            OrderAlert(
              title: 'Order Placed!',
              body: 'Your meal is being processed.',
              token: token,
              type: AlertType.success,
              orderId: orderId,
            ),
          );
        }
      }

      // 2. Ready Check (Per Item)
      for (var item in items) {
        final itemId = item['itemId'] as String?;
        final itemName = item['nameSnapshot'] as String? ?? 'Item';
        final itemStatus = item['itemStatus'] as String?;

        if (itemId != null && itemStatus == 'ready') {
          final key = '$orderId:$itemId:ready';
          if (!_notifiedKeys.contains(key)) {
            _notifiedKeys.add(key);
            
            // Only alert if this is a fresh update occurring right now
            if (isFreshUpdate) {
              showAlert(
                OrderAlert(
                  title: 'Item Ready',
                  body: '$itemName is READY',
                  token: token,
                  type: AlertType.ready,
                  orderId: orderId,
                ),
              );
            }
          }
        }
      }

      // 3. Served Check
      if (status == 'served') {
        final key = '$orderId:served';
        if (!_notifiedKeys.contains(key)) {
          _notifiedKeys.add(key);
          
          // Only alert if this is a fresh update occurring right now
          if (isFreshUpdate) {
            showAlert(
              OrderAlert(
                title: 'Order Served',
                body: 'Enjoy your meal!',
                token: token,
                type: AlertType.status,
                orderId: orderId,
              ),
            );
          }
        }
      }
    }
  }

  void showAlert(OrderAlert alert) {
    state = alert;

    // Persist to notification center history
    ref
        .read(studentNotificationServiceProvider)
        .addNotification(
          title: alert.title,
          body: alert.token != null
              ? 'Token #${alert.token}: ${alert.body}'
              : alert.body,
          type: alert.type.name,
          orderId: alert.orderId,
        );

    // Auto-dismiss after 7 seconds (Premium policy)
    Future.delayed(const Duration(seconds: 7), () {
      if (state == alert) {
        dismiss();
      }
    });
  }

  void dismiss() {
    state = null;
  }
}

final studentAlertProvider =
    NotifierProvider<StudentAlertNotifier, OrderAlert?>(() {
      return StudentAlertNotifier();
    });
