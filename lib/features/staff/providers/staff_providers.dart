import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../core/utils/session_status_resolver.dart';
import '../../../core/models/admin_models.dart';
import '../../../core/utils/time_helper.dart';

// ---------------------------------------------------------------------------
// Auth guard helper — returns a stream that emits null and stops if not signed in
// ---------------------------------------------------------------------------
bool _isSignedIn() => FirebaseAuth.instance.currentUser != null;

// Classified sessions for the current day
final currentDaySessionsWithStatusProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
      // Use reactive auth state rather than direct FirebaseAuth instance
      final authState = ref.watch(authStateProvider);

      return authState.when(
        data: (user) {
          if (user == null) return const Stream.empty();

          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

          // Stream the dailyMenu doc for release status
          final menuStream = FirebaseFirestore.instance
              .collection('canteens')
              .doc('default')
              .collection('dailyMenus')
              .doc(today)
              .snapshots();

          // Stream the sessions subcollection
          final sessionsStream = FirebaseFirestore.instance
              .collection('canteens')
              .doc('default')
              .collection('dailyMenus')
              .doc(today)
              .collection('sessions')
              .snapshots();

          // Combine both streams
          return menuStream.asyncExpand((menuSnap) {
            final isReleased = menuSnap.data()?['status'] == 'released';
            return sessionsStream.map((sessionsSnap) {
              final now = DateTime.now();
              return sessionsSnap.docs.map((d) {
                final data = d.data();
                data['id'] = d.id;

                final state = SessionStatusResolver.computeSessionState(
                  selectedDate: DateTime.now(),
                  now: now,
                  startTimeStr: data['startTime'] ?? '',
                  endTimeStr: data['endTime'] ?? '',
                  isReleased: isReleased,
                );

                data['timeState'] = state.timeState.name;
                data['isLive'] = state.isLive;
                data['isPast'] = state.isPast;

                return data;
              }).toList();
            });
          });
        },
        loading: () => const Stream.empty(),
        error: (_, __) => const Stream.empty(),
      );
    });

// Provides available sessions (Legacy wrapper)
final currentDaySessionsProvider =
    Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
      return ref.watch(currentDaySessionsWithStatusProvider);
    });

// Selected session ID
final staffSelectedSessionIdProvider = StateProvider<String?>((ref) => null);

// Selected slot ID
final staffSelectedSlotIdProvider = StateProvider<String?>((ref) => null);

// Selected filter state (pending, scheduled, ready, partial, served, skipped)
final staffSelectedFilterProvider = StateProvider<String>((ref) => 'all');

// Provides ALL slots for the entire day (across all sessions)
final staffAllDaySlotsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final sessionsAsync = ref.watch(currentDaySessionsWithStatusProvider);
  final sessions = sessionsAsync.valueOrNull ?? [];
  if (sessions.isEmpty) return [];

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final List<Map<String, dynamic>> allSlots = [];

  for (var session in sessions) {
    final sessionId = session['id'];
    final slotsRef = await FirebaseFirestore.instance
        .collection('canteens')
        .doc('default')
        .collection('dailyMenus')
        .doc(today)
        .collection('sessions')
        .doc(sessionId)
        .collection('slots')
        .get();

    for (var d in slotsRef.docs) {
      final sData = d.data();
      sData['id'] = d.id;
      sData['sessionId'] = sessionId; // Crucial for mapping back
      sData['sessionName'] = session['name'] ?? session['sessionNameSnapshot'];
      allSlots.add(sData);
    }
  }

  allSlots.sort(
    (a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String),
  );
  return allSlots;
});

// Legacy wrapper (now uses all day slots but preserves existing logic if needed)
final staffSessionSlotsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final activeTab = ref.watch(staffKitchenTabProvider);
  final allSlots = await ref.watch(staffAllDaySlotsProvider.future);

  if (activeTab == 'fullday') return allSlots;

  final sessionsAsync = ref.watch(currentDaySessionsWithStatusProvider);
  final sessions = sessionsAsync.valueOrNull ?? [];

  String? targetSessionId;
  if (activeTab == 'current') {
    targetSessionId = ref.watch(staffSelectedSessionIdProvider);
  } else if (activeTab == 'upcoming') {
    for (var s in sessions) {
      if (s['timeState'] == 'upcoming') {
        targetSessionId = s['id'];
        break;
      }
    }
  }

  if (targetSessionId == null) return allSlots; // Show all if none selected

  return allSlots.where((s) => s['sessionId'] == targetSessionId).toList();
});

// Provides the stream of orders for the selected session, slot, and filter
final staffOrdersStreamProvider =
    StreamProvider<List<DocumentSnapshot<Map<String, dynamic>>>>((ref) {
      final authState = ref.watch(authStateProvider);

      return authState.when(
        data: (user) {
          if (user == null) return Stream.value([]);

          final sessionId = ref.watch(staffSelectedSessionIdProvider);
          final slotId = ref.watch(staffSelectedSlotIdProvider);
          final filter = ref.watch(staffSelectedFilterProvider);

          if (sessionId == null || slotId == null) {
            return Stream.value([]);
          }

          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection('canteens')
              .doc('default')
              .collection('orders')
              .where('orderDate', isEqualTo: today)
              .where('sessionId', isEqualTo: sessionId)
              .where('slotId', isEqualTo: slotId);

          if (filter == 'all') {
            // 'All' shows every active token (pending, ready, partial, skipped)
            // Tokens must NOT disappear — they stay here regardless of sub-chip status
            query = query.where(
              'statusCategory',
              whereIn: ['pending', 'scheduled', 'ready', 'partial', 'skipped'],
            );
          } else {
            query = query.where('statusCategory', isEqualTo: filter);
          }

          return query.snapshots().map((snap) {
            final docs = snap.docs.toList();

            if (filter == 'all') {
              // Priority sort...
              docs.sort((a, b) {
                int _priorityGroup(DocumentSnapshot<Map<String, dynamic>> doc) {
                  final data = doc.data()!;
                  final cat = (data['statusCategory'] as String? ?? 'pending')
                      .toLowerCase();
                  final items = data['items'] as List? ?? [];

                  if (cat == 'partial') return 0;

                  if (cat == 'skipped') {
                    final anyItemReady = items.any((item) {
                      final iStatus = (item['itemStatus'] as String? ?? '')
                          .toLowerCase();
                      return iStatus == 'ready' || iStatus == 'served';
                    });
                    final readyBeforeSkip =
                        data['readyBeforeSkip'] as bool? ?? anyItemReady;
                    if (readyBeforeSkip) return 2;
                    return 0;
                  }
                  return 1;
                }

                final aPriority = _priorityGroup(a);
                final bPriority = _priorityGroup(b);

                if (aPriority != bPriority)
                  return aPriority.compareTo(bPriority);

                final aNum =
                    int.tryParse(a.data()['tokenNumber']?.toString() ?? '0') ??
                    0;
                final bNum =
                    int.tryParse(b.data()['tokenNumber']?.toString() ?? '0') ??
                    0;
                return aNum.compareTo(bNum);
              });
            } else {
              docs.sort((a, b) {
                final aNum =
                    int.tryParse(a.data()['tokenNumber']?.toString() ?? '0') ??
                    0;
                final bNum =
                    int.tryParse(b.data()['tokenNumber']?.toString() ?? '0') ??
                    0;
                return aNum.compareTo(bNum);
              });
            }

            return docs;
          });
        },
        loading: () => Stream.value([]),
        error: (_, __) => Stream.value([]),
      );
    });

// =========================================================================
// KITCHEN PREP AGGREGATION
// =========================================================================

final staffKitchenTabProvider = StateProvider<String>(
  (ref) => 'current',
); // 'current', 'upcoming', 'fullday'

// =========================================================================
// REAL-TIME PULSE & MONITORING
// =========================================================================

// A periodic pulse to drive countdowns and pace calculations
final currentTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

// A computed provider that determines if the staff is Ahead or Slow
final staffSessionPaceProvider = Provider<String?>((ref) {
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
  final slotsAsync = ref.watch(staffSessionSlotsProvider);

  return slotsAsync.whenData((slots) {
    if (slots.isEmpty) return null;

    // Find the "LIVE" slot
    Map<String, dynamic>? liveSlot;
    for (var s in slots) {
      final startDt = TimeHelper.parseSessionTime(s['startTime'], now);
      final endDt = TimeHelper.parseSessionTime(s['endTime'], now);
      if (startDt != null &&
          endDt != null &&
          TimeHelper.isTimeInWindow(now, startDt, endDt)) {
        liveSlot = s;
        break;
      }
    }

    if (liveSlot == null) return null;

    final slotId = liveSlot['id'];
    final startTime = TimeHelper.parseSessionTime(liveSlot['startTime'], now)!;
    final endTime = TimeHelper.parseSessionTime(liveSlot['endTime'], now)!;
    final totalDuration = endTime.difference(startTime).inMinutes;
    final elapsed = now.difference(startTime).inMinutes;

    if (elapsed <= 0) return null;

    // We need to watch todayAllOrdersStreamProvider here to get all orders for the day
    // and then filter by slotId.
    final ordersAsync = ref.watch(todayAllOrdersStreamProvider);

    return ordersAsync.maybeWhen(
      data: (orders) {
        final slotOrders = orders
            .where((o) => o.data()!['slotId'] == slotId)
            .toList();
        if (slotOrders.isEmpty) return null;

        int totalTokens = slotOrders.length;
        int servedTokens = slotOrders.where((o) {
          final status = (o.data()!['statusCategory'] as String? ?? '')
              .toLowerCase();
          return status == 'served';
        }).length;

        if (totalTokens == 0) return null;

        // Target progress: (elapsed / totalDuration) * totalTokens
        final expectedServed = (elapsed / totalDuration) * totalTokens;

        // Threshold for status
        if (servedTokens > expectedServed * 1.1) return "Ahead";
        if (servedTokens < expectedServed * 0.9) return "Slow";
        return "On Track";
      },
      orElse: () => null,
    );
  }).value;
});

// A computed provider that calculates the next slot alert message
final nextSlotAlertProvider = Provider<String?>((ref) {
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
  final slotsAsync = ref.watch(staffSessionSlotsProvider);

  return slotsAsync.whenData((slots) {
    if (slots.isEmpty) return null;

    // Find the next upcoming slot
    Map<String, dynamic>? nextSlot;
    for (var s in slots) {
      final startDt = TimeHelper.parseSessionTime(s['startTime'], now);
      if (startDt != null && now.isBefore(startDt)) {
        nextSlot = s;
        break;
      }
    }

    if (nextSlot == null) return null;

    final startDt = TimeHelper.parseSessionTime(nextSlot['startTime'], now)!;
    final endDt = TimeHelper.parseSessionTime(nextSlot['endTime'], now)!;
    final interval = endDt.difference(startDt).inMinutes;
    final diff = startDt.difference(now);

    // Threshold logic from user:
    // >= 30 min interval -> 10 min threshold
    // < 30 min -> interval threshold
    // < 5 min -> 1 min threshold
    int thresholdMinutes = 10;
    if (interval < 5) {
      thresholdMinutes = 1;
    } else if (interval < 30) {
      thresholdMinutes = interval;
    } else if (interval >= 30) {
      thresholdMinutes = 10;
    }

    if (diff.inSeconds > 0 && diff.inMinutes < thresholdMinutes) {
      final m = diff.inMinutes;
      final s = diff.inSeconds % 60;
      final timerStr =
          "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
      return "Next slot in $timerStr";
    }

    return null;
  }).value;
});

// Provides ALL orders for today to aggregate
final todayAllOrdersStreamProvider =
    StreamProvider<List<DocumentSnapshot<Map<String, dynamic>>>>((ref) {
      if (!_isSignedIn()) return Stream.value([]);

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      return FirebaseFirestore.instance
          .collection('canteens')
          .doc('default')
          .collection('orders')
          .where('orderDate', isEqualTo: today)
          .snapshots()
          .map((snap) => snap.docs);
    });

// Provides categories for mapping IDs to names
final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('canteens')
      .doc('default')
      .collection('categories')
      .orderBy('order')
      .snapshots()
      .map(
        (snap) => snap.docs.map((d) => CategoryModel.fromFirestore(d)).toList(),
      );
});

// Provides the selected slot ID for kitchen filtering
final staffKitchenSelectedSlotIdProvider = StateProvider<String?>(
  (ref) => null,
);

// A computed provider that groups items by Category -> Items mapped with demand/prepared qty
final kitchenAggregationProvider = Provider<Map<String, dynamic>>((ref) {
  final activeTab = ref.watch(staffKitchenTabProvider);
  final selectedSlotId = ref.watch(staffKitchenSelectedSlotIdProvider);
  final ordersAsync = ref.watch(todayAllOrdersStreamProvider);
  final sessionsAsync = ref.watch(currentDaySessionsWithStatusProvider);
  final categoriesAsync = ref.watch(categoriesProvider);
  final currentSessionId = ref.watch(staffSelectedSessionIdProvider);
  final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

  return ordersAsync.maybeWhen(
    data: (docs) {
      // Create a map for category names
      final Map<String, String> categoryNames = {};
      categoriesAsync.whenData((list) {
        for (var c in list) {
          categoryNames[c.id] = c.name;
        }
      });

      // Find the LIVE slot overall
      Map<String, dynamic>? liveSlot;
      String? liveSessionId;
      sessionsAsync.whenData((sessions) {
        for (var s in sessions) {
          if (s['isLive'] == true) liveSessionId = s['id'];
        }
      });

      // Determine the upcoming session ID
      String? upcomingSessionId;
      sessionsAsync.whenData((sessions) {
        for (var s in sessions) {
          if (s['timeState'] == 'upcoming') {
            upcomingSessionId = s['id'];
            break;
          }
        }
      });

      final Map<String, Map<String, dynamic>> aggregated = {};
      int totalItemsCount = 0;
      int pendingPrepCount = 0;

      for (var doc in docs) {
        final data = doc.data()!;
        final sessionId = data['sessionId'];
        final slotId = data['slotId'];

        // Filter by tab
        if (activeTab == 'current') {
          final effectiveSessionId = currentSessionId ?? liveSessionId;
          if (sessionId != effectiveSessionId) continue;
        } else if (activeTab == 'upcoming') {
          if (sessionId != upcomingSessionId) continue;
        }

        // Filter by specific slot if selected
        if (selectedSlotId != null && slotId != selectedSlotId) continue;

        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        for (var item in items) {
          final catId = item['categoryIdSnapshot'] ?? 'Other';
          final name = item['nameSnapshot'] ?? 'Unknown Item';
          final itemId = item['itemId'];
          final qty = item['quantity'] as int? ?? 1;
          final isPreReady = item['isPreReady'] ?? false;
          final isReady = item['itemStatus'] == 'ready' || item['itemStatus'] == 'served';

          // Determine if this specific item is from the current "LIVE" slot
          // Note: we'd need slot timing data here, but we can approximate or use IDs
          // For now, if we are in 'current' tab and slotId matches live slot, it's urgent.
          // BUT: we don't have the liveSlotId easily here without more lookups.
          // Let's assume ANY item in the 'current' tab is urgent, but upcoming slots are ahead.
          
          if (!aggregated.containsKey(catId)) {
            aggregated[catId] = {
              'categoryName': categoryNames[catId] ?? catId,
              'items': <String, dynamic>{},
              'totalQty': 0,
            };
          }

          final catEntry = aggregated[catId]!;
          catEntry['totalQty'] += qty;
          totalItemsCount += qty;

          final catItems = catEntry['items'] as Map<String, dynamic>;
          if (!catItems.containsKey(itemId)) {
            catItems[itemId] = {
              'itemId': itemId,
              'name': name,
              'orderedQty': 0,
              'preparedQty': 0,
              'isPreReady': isPreReady,
              'isHighDemand': false,
              'categories': <String>{}, 
            };
          }

          catItems[itemId]['orderedQty'] += qty;
          if (isReady) {
            catItems[itemId]['preparedQty'] += qty;
          } else {
            pendingPrepCount += qty;
          }
        }
      }

      final List<Map<String, dynamic>> flatItems = [];
      aggregated.forEach((catId, catData) {
        final itemsMap = catData['items'] as Map<String, dynamic>;
        itemsMap.forEach((itemId, itemData) {
          flatItems.add(itemData);
        });
      });

      // Sort by remaining demand
      flatItems.sort((a, b) {
        final remA = (a['orderedQty'] as int) - (a['preparedQty'] as int);
        final remB = (b['orderedQty'] as int) - (b['preparedQty'] as int);
        return remB.compareTo(remA);
      });

      // High demand
      final List<Map<String, dynamic>> highDemandItems = flatItems.take(4).map((item) {
        return {...item, 'label': activeTab == 'fullday' ? 'Daily Peak' : 'Urgent'};
      }).toList();

      return {
        'categories': aggregated,
        'highDemand': highDemandItems,
        'totalDemand': totalItemsCount,
        'pendingPrep': pendingPrepCount,
      };
    },
    orElse: () => {
      'categories': <String, dynamic>{},
      'highDemand': <Map<String, dynamic>>[],
      'totalDemand': 0,
      'pendingPrep': 0,
    },
  );
});
