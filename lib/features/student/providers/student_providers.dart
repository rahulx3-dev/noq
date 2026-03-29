import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/student_menu_service.dart';
import '../../../core/utils/session_status_resolver.dart';
import 'student_orders_provider.dart';
import '../../../core/models/student_models.dart';

final studentMenuServiceProvider = Provider((ref) {
  return StudentMenuService();
});

/// A stream that watches today's daily menu configuration.
/// The date is always 'yyyy-MM-dd' for the current day.
// NOT autoDispose — keeps the menu stream alive across tab switches for instant updates
final todayStudentMenuProvider = StreamProvider<StudentDailyMenu?>((ref) {
  final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final service = ref.watch(studentMenuServiceProvider);
  return service.watchDailyMenu(date);
});

/// Categories lookup map for resolving category IDs to names.
final categoriesMapProvider = FutureProvider.autoDispose<Map<String, String>>((
  ref,
) async {
  final service = ref.watch(studentMenuServiceProvider);
  return await service.fetchCategoriesMap();
});

/// Simple local state for favorited items.
final favoritesProvider = StateProvider<Set<String>>((ref) => {});

/// Provider to aggregate the student's most ordered items from history.
final mostOrderedItemsProvider =
    Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final allOrders = ref.watch(studentOrdersStreamProvider).value ?? [];
      final menu = ref.watch(todayStudentMenuProvider).value;

      // 1. Filter for final/successful statuses
      final validOrders = allOrders.where((o) {
        final status = (o['orderStatus'] as String? ?? '').toLowerCase();
        return ['delivered', 'served', 'completed'].contains(status);
      });

      // 2. Count frequency per itemId
      final Map<String, int> frequencyMap = {};
      final Map<String, Map<String, dynamic>> itemSnapshots = {};

      for (var order in validOrders) {
        final items = order['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          final id = item['itemId'] as String? ?? '';
          if (id.isEmpty) continue;

          final qty = item['quantity'] as int? ?? 1;
          frequencyMap[id] = (frequencyMap[id] ?? 0) + qty;

          // Store the latest snapshot data for display
          if (!itemSnapshots.containsKey(id)) {
            itemSnapshots[id] = Map<String, dynamic>.from(item);
          }
        }
      }

      // 3. Sort by frequency descending
      final sortedIds = frequencyMap.keys.toList()
        ..sort((a, b) => frequencyMap[b]!.compareTo(frequencyMap[a]!));

      // 4. Match against today's menu for availability
      final List<Map<String, dynamic>> results = [];
      final now = DateTime.now();

      for (var id in sortedIds) {
        final snapshot = itemSnapshots[id]!;
        StudentMenuItem? currentItem;
        String? sessionStartTime;
        String? sessionEndTime;

        if (menu != null) {
          for (var session in menu.sessions) {
            final found = session.items.where((it) => it.itemId == id);
            if (found.isNotEmpty) {
              currentItem = found.first;
              sessionStartTime = session.startTime;
              sessionEndTime = session.endTime;
              break;
            }
          }
        }

        bool isCurrentlyOrderable = false;
        if (currentItem != null && currentItem.isAvailable && (menu?.isReleased ?? false)) {
          if (currentItem.isPreReady) {
            isCurrentlyOrderable = currentItem.remainingStock > 0;
          } else if (sessionStartTime != null && sessionEndTime != null) {
            final state = SessionStatusResolver.computeSessionState(
              selectedDate: DateTime.parse(menu!.date),
              now: now,
              startTimeStr: sessionStartTime,
              endTimeStr: sessionEndTime,
              isReleased: menu.isReleased,
            );
            isCurrentlyOrderable = !state.isPast && currentItem.remainingStock > 0;
          }
        }

        results.add({
          'itemId': id,
          'name': snapshot['nameSnapshot'] ?? 'Item',
          'price': snapshot['priceSnapshot'] ?? 0.0,
          'imageUrl': snapshot['imageUrlSnapshot'] ?? '',
          'frequency': frequencyMap[id],
          'isAvailableToday': isCurrentlyOrderable,
          'currentItem': currentItem,
        });
      }

      return results.take(8).toList(); 
    });

/// Possible popularity levels for pulsing indicators
enum PopularityLevel { popular, trending, fresh, rare, normal }

/// Provider to categorize items based on order frequency
final foodPopularityProvider = Provider.autoDispose.family<PopularityLevel, String>((ref, itemId) {
  final mostOrdered = ref.watch(mostOrderedItemsProvider);
  
  // Find item in frequency list
  final itemIdx = mostOrdered.indexWhere((it) => it['itemId'] == itemId);
  if (itemIdx >= 0) {
    if (itemIdx < 3) return PopularityLevel.popular;
    return PopularityLevel.trending;
  }

  // Fallback: only count SERVED/COMPLETED orders to prevent bogus trending badges for new items
  final allOrders = ref.watch(studentOrdersStreamProvider).value ?? [];
  int count = 0;
  for (var o in allOrders) {
    final status = (o['orderStatus'] as String? ?? '').toLowerCase();
    // Only orders that actually completed count toward popularity
    if (!['served', 'delivered', 'completed'].contains(status)) continue;
    final items = o['items'] as List? ?? [];
    for (var i in items) {
      if (i['itemId'] == itemId) count += (i['quantity'] as int? ?? 1);
    }
  }

  if (count > 20) return PopularityLevel.popular;
  if (count > 10) return PopularityLevel.trending;
  if (count > 0 && count < 3) return PopularityLevel.rare;
  // count == 0 means it's a new/fresh item — show NO badge (normal)
  return PopularityLevel.normal;
});

/// Aggregates metadata for favorited items from both today's menu and history.
final favoriteItemsMetadataProvider =
    Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final favorites = ref.watch(favoritesProvider);
      final allOrders = ref.watch(studentOrdersStreamProvider).value ?? [];
      final menu = ref.watch(todayStudentMenuProvider).value;

      // 1. Collect snapshots from history for metadata fallback
      final Map<String, Map<String, dynamic>> itemSnapshots = {};
      for (var order in allOrders) {
        final items = order['items'] as List<dynamic>? ?? [];
        for (var item in items) {
          final id = item['itemId'] as String? ?? '';
          if (id.isNotEmpty) {
            itemSnapshots[id] = Map<String, dynamic>.from(item);
          }
        }
      }

      // 2. Map favorites to metadata
      final List<Map<String, dynamic>> results = [];
      for (var id in favorites) {
        // Try to find in today's menu first for live availability
        StudentMenuItem? currentItem;
        if (menu != null) {
          for (var session in menu.sessions) {
            final found = session.items.where((it) => it.itemId == id);
            if (found.isNotEmpty) {
              currentItem = found.first;
              break;
            }
          }
        }

        final snapshot = itemSnapshots[id];

        // If we have no data at all, skip (fallback to minimal info if possible)
        if (currentItem == null && snapshot == null) {
          results.add({
            'itemId': id,
            'name': 'Unknown Item',
            'price': 0.0,
            'imageUrl': '',
            'isAvailableToday': false,
            'currentItem': null,
          });
          continue;
        }

        results.add({
          'itemId': id,
          'name': currentItem?.nameSnapshot ?? snapshot?['nameSnapshot'] ?? 'Item',
          'price': currentItem?.priceSnapshot ?? snapshot?['priceSnapshot'] ?? 0.0,
          'imageUrl':
              currentItem?.imageUrlSnapshot ??
              snapshot?['imageUrlSnapshot'] ??
              '',
          'isAvailableToday':
              currentItem != null &&
              currentItem.isAvailable &&
              (menu?.isReleased ?? false),
          'currentItem': currentItem,
        });
      }

      return results;
    });
