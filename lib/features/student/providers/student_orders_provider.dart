import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qcutapp/core/providers.dart';
import 'package:qcutapp/core/utils/order_classification_helper.dart';

final studentOrdersStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final authState = ref.watch(authStateProvider);
      final user = authState.value;
      if (user == null) return Stream.value([]);

      // Watch all orders for this student
      return FirebaseFirestore.instance
          .collection('canteens')
          .doc('default')
          .collection('orders')
          .where('studentUid', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((d) {
                  final data = d.data();
                  data['orderId'] = d.id;
                  return data;
                })
                .where((order) => order['isHiddenByStudent'] != true)
                .toList(),
          );
    });

final studentActiveOrdersProvider =
    Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final allOrders = ref.watch(studentOrdersStreamProvider).value ?? [];
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. Group orders by checkoutGroupId
      final Map<String, List<Map<String, dynamic>>> groups = {};
      for (final order in allOrders) {
        final groupId =
            order['checkoutGroupId'] ?? order['orderId'] ?? 'unknown';
        groups.putIfAbsent(groupId, () => []).add(order);
      }

      // 2. Filter aggregated groups
      final List<Map<String, dynamic>> activeGroups = [];
      groups.forEach((groupId, orders) {
        // Group is active if ANY part is pending, ready, skipped, scheduled, etc.
        final isActiveStatus = OrderClassificationHelper.isGroupActive(orders);

        // We check if it is not from a past day.
        final firstOrder = orders.first;
        final orderDateStr = OrderClassificationHelper.getOrderDateStr(
          firstOrder,
          todayStr,
        );
        final isPastDay = orderDateStr.compareTo(todayStr) < 0;

        if (isActiveStatus && !isPastDay) {
          // Merge details for UI - use the first order as template but aggregate status
          final aggregate = Map<String, dynamic>.from(firstOrder);
          aggregate['orderStatus'] =
              OrderClassificationHelper.getAggregateStatus(orders);
          aggregate['isAggregated'] = true;
          aggregate['subOrders'] = orders;
          activeGroups.add(aggregate);
        }
      });

      return activeGroups;
    });

final studentOrderHistoryProvider =
    Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final allOrders = ref.watch(studentOrdersStreamProvider).value ?? [];
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 1. Group orders by checkoutGroupId
      final Map<String, List<Map<String, dynamic>>> groups = {};
      for (final order in allOrders) {
        final groupId =
            order['checkoutGroupId'] ?? order['orderId'] ?? 'unknown';
        groups.putIfAbsent(groupId, () => []).add(order);
      }

      // 2. Filter aggregated groups
      final List<Map<String, dynamic>> historyGroups = [];
      groups.forEach((groupId, orders) {
        final isActiveStatus = OrderClassificationHelper.isGroupActive(orders);
        final firstOrder = orders.first;
        final orderDateStr = OrderClassificationHelper.getOrderDateStr(
          firstOrder,
          todayStr,
        );
        final isPastDay = orderDateStr.compareTo(todayStr) < 0;

        // In history if it is NOT active status, OR if it's from a past day.
        if (!isActiveStatus || isPastDay) {
          final aggregate = Map<String, dynamic>.from(firstOrder);
          aggregate['orderStatus'] =
              OrderClassificationHelper.getAggregateStatus(orders);
          aggregate['isAggregated'] = true;
          aggregate['subOrders'] = orders;
          historyGroups.add(aggregate);
        }
      });

      // Sort by date descending
      historyGroups.sort((a, b) {
        final timeA =
            (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        final timeB =
            (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
        return timeB.compareTo(timeA);
      });

      return historyGroups;
    });
