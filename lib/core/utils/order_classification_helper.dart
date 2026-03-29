import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'time_helper.dart';

class OrderClassificationHelper {
  /// Defines which statuses are considered "Active" in the operational flow.
  /// Note: 'skipped' is considered active because it can still be served if the user returns.
  static const List<String> activeStatuses = [
    'pending',
    'preparing',
    'ready',
    'partial',
    'partial served',
    'skipped',
    'scheduled',
  ];

  /// Defines which statuses are considered finalized/historical.
  static const List<String> finalStatuses = ['served', 'cancelled', 'expired'];

  /// Determines if a group of orders (linked by checkoutGroupId) is still active.
  static bool isGroupActive(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return false;

    // If any single order in the group is in an active status, the whole group is active.
    return orders.any((order) {
      final status = (order['orderStatus'] as String? ?? 'pending').toLowerCase();
      return activeStatuses.contains(status);
    });
  }

  /// Calculates the aggregate status for a group of orders.
  static String getAggregateStatus(List<Map<String, dynamic>> orders) {
    if (orders.isEmpty) return 'none';

    final statuses = orders
        .map((o) => (o['orderStatus'] as String? ?? 'pending').toLowerCase())
        .toSet();

    // Priority 1: If any are 'partial', the group is 'partial'
    if (statuses.contains('partial')) return 'partial';
    
    // Priority 2: If any are 'partial served', the group is 'partial served'
    if (statuses.contains('partial served')) return 'partial served';

    // Priority 3: If any are 'ready', the group is 'ready' (attention required)
    if (statuses.contains('ready')) return 'ready';

    // Priority 4: If any are 'skipped', the group is 'skipped'
    if (statuses.contains('skipped')) return 'skipped';

    // Priority 5: If any are 'preparing', the group is 'preparing'
    if (statuses.contains('preparing')) return 'preparing';

    // Priority 5: If any are 'pending', we check if it is 'scheduled' or truly 'pending'
    if (statuses.contains('pending')) {
      // Check if the overall group is scheduled (all pending items are for future slots)
      final allPendingScheduled = orders.every((o) {
        final s = (o['orderStatus'] as String? ?? 'pending').toLowerCase();
        if (s != 'pending') return true; // Non-pending items don't block "scheduled" label
        return isOrderScheduled(o);
      });

      return allPendingScheduled ? 'scheduled' : 'pending';
    }

    // Priority 6: If all are 'served', the group is 'served'
    if (statuses.every((s) => s == 'served')) return 'served';

    // Priority 7: If all are 'cancelled', the group is 'cancelled'
    if (statuses.every((s) => s == 'cancelled')) return 'cancelled';

    return 'pending';
  }

  /// Helper to check if a specific order doc is for an upcoming session/slot.
  static bool isOrderScheduled(Map<String, dynamic> order) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final orderDate = order['orderDate'] as String?;

    // If it's a future date, it's definitely scheduled
    if (orderDate != null && orderDate.compareTo(todayStr) > 0) {
      return true;
    }

    // If it's today, check the slot start time
    if (orderDate == todayStr) {
      final startTimeStr = order['slotStartTime'] as String?;
      if (startTimeStr != null) {
        try {
          final today = DateTime(now.year, now.month, now.day);
          final slotStartTime = TimeHelper.parseSessionTime(startTimeStr, today);
          // If the slot hasn't started yet, it's scheduled
          if (slotStartTime != null && slotStartTime.isAfter(now)) {
            return true;
          }
        } catch (_) {}
      }
    }

    return false;
  }

  /// Extracts the order date string for filtering purposes.
  static String getOrderDateStr(
    Map<String, dynamic> order,
    String fallbackToday,
  ) {
    final orderDate = order['orderDate'] as String?;
    if (orderDate != null) return orderDate;

    final createdAt = order['createdAt'] as Timestamp?;
    if (createdAt != null) {
      final date = createdAt.toDate();
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    }

    return fallbackToday;
  }
}
