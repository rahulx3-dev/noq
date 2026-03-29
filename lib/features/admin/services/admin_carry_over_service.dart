import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/utils/time_helper.dart';
import '../../../core/models/admin_models.dart';
import '../widgets/leftover_carry_popup.dart';

class AdminCarryOverService {
  final Ref ref;

  AdminCarryOverService(this.ref);

  Future<void> prepareAndShowCarryOver({
    required BuildContext context,
    required String sessionId,
    required String sessionName,
    required VoidCallback onProcessed,
  }) async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      // 1. Fetch items
      final itemsSnap = await ref.read(firestoreServiceProvider)
          .getSessionItemsStream('default', todayStr, sessionId).first;
      
      final leftovers = itemsSnap.docs.map((doc) {
          final data = doc.data();
          final stock = data['remainingStock'] ?? data['availableStock'] ?? 0;
          return {
            'itemId': doc.id,
            'name': data['nameSnapshot'] ?? doc.id,
            'stock': stock,
            'price': data['priceSnapshot'] ?? 0,
            'categoryId': data['categoryIdSnapshot'] ?? 'Other',
            'categoryIds': data['categoryIdsSnapshot'] ?? [data['categoryIdSnapshot'] ?? 'Other'],
            'imageUrl': data['imageUrlSnapshot'] ?? '',
            'description': data['descriptionSnapshot'] ?? '',
            'isPreReady': data['isPreReady'] ?? false,
          };
      }).where((it) => (it['stock'] as int) > 0 && !(it['isPreReady'] as bool)).toList();

      if (leftovers.isEmpty) {
        onProcessed();
        return;
      }

      // 2. Find closest future released session
      final released = ref.read(releasedSessionsProvider(todayStr)).value ?? [];
      
      // Candidate target sessions must be released and their startTime must be after the current session's endTime
      // Or just chronologically after the current session in the list.
      // Let's find all released sessions and sort them.
      final releasedSessionIds = released.map((r) => r['sessionId'] as String).toSet();
      final sessions = ref.read(sessionsStreamProvider).value ?? [];
      
      final sortedSessions = List<SessionModel>.from(sessions)
        ..sort((a, b) {
          final timeA = TimeHelper.parseSessionTime(a.startTime, now) ?? DateTime(2000);
          final timeB = TimeHelper.parseSessionTime(b.startTime, now) ?? DateTime(2000);
          return timeA.compareTo(timeB);
        });

      final currentIndex = sortedSessions.indexWhere((s) => s.id == sessionId);
      SessionModel? nextTarget;
      
      if (currentIndex != -1) {
        // Look for the first released session AFTER this one
        for (int i = currentIndex + 1; i < sortedSessions.length; i++) {
          if (releasedSessionIds.contains(sortedSessions[i].id)) {
            nextTarget = sortedSessions[i];
            break;
          }
        }
      }

      if (nextTarget == null) {
        // End of day logic
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('End of Day'),
              content: Text('$sessionName ended with ${leftovers.length} leftovers. Since no future released sessions were found, these items can no longer be carried over today.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onProcessed();
                  }, 
                  child: const Text('Acknowledge'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // 3. Show Popup
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Center(
            child: SingleChildScrollView(
              child: LeftoverCarryPopup(
                items: leftovers,
                fromSessionName: sessionName,
                toSessionName: nextTarget!.name,
                onDismiss: () {
                  Navigator.pop(ctx);
                  onProcessed();
                },
                onConfirm: (selected) async {
                  Navigator.pop(ctx);
                  if (selected.isNotEmpty) {
                    await ref.read(firestoreServiceProvider).carryOverStock(
                      canteenId: 'default',
                      date: todayStr,
                      fromSessionId: sessionId,
                      toSessionId: nextTarget!.id,
                      itemsToCarry: selected,
                    );
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Successfully carried over to ${nextTarget!.name}')),
                      );
                    }
                  }
                  onProcessed();
                },
              ),
            ),
          ),
        );
      }
      
    } catch (e) {
      debugPrint('Error in prepareAndShowCarryOver: $e');
      onProcessed();
    }
  }
}

final adminCarryOverServiceProvider = Provider((ref) => AdminCarryOverService(ref));
