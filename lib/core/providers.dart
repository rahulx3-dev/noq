import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qcutapp/core/models/user_profile_model.dart';
import 'package:qcutapp/core/services/auth_service.dart';
import 'package:qcutapp/core/models/canteen_model.dart';
import 'package:qcutapp/core/services/firestore_service.dart';
import 'package:qcutapp/core/models/admin_models.dart';
import 'package:qcutapp/core/utils/time_helper.dart';
import 'package:qcutapp/features/student/services/student_order_service.dart';

// ── Service Providers ──────────────────────────────────────────────────

/// Provides the singleton [AuthService] instance.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provides the singleton [FirestoreService] instance.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provides the singleton [StudentOrderService] instance.
final studentOrderServiceProvider = Provider<StudentOrderService>((ref) {
  return StudentOrderService();
});

// ── Auth State ─────────────────────────────────────────────────────────

/// Emits the current [User?] whenever auth state changes (login / logout).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ── User Profile ───────────────────────────────────────────────────────

/// Fetches the [UserProfile] for the currently authenticated user.
///
/// Returns `null` when no user is signed in or when the Firestore document
/// does not exist yet.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      final firestore = ref.read(firestoreServiceProvider);
      return firestore.watchUserProfile(user.uid).map((doc) {
        if (!doc.exists) return null;
        return UserProfile.fromFirestore(doc);
      });
    },
    loading: () => Stream.value(null),
    error: (_, s) => Stream.value(null),
  );
});

/// Provides the [CanteenModel] for the app.
/// Guarded: only fetches once admin role is confirmed.
final canteenProvider = FutureProvider<CanteenModel?>((ref) async {
  final profileAsync = ref.watch(userProfileProvider);
  // Only proceed once the profile has loaded and role is admin
  final profile = profileAsync.valueOrNull;
  if (profile == null || profile.role != UserRole.admin) return null;
  final firestore = ref.read(firestoreServiceProvider);
  final doc = await firestore.getCanteen('default');
  if (!doc.exists) return null;
  return CanteenModel.fromFirestore(doc);
});

/// Guarded: only runs for admin users.
final dailyMenuStatusProvider = FutureProvider.family<bool, String>((
  ref,
  date,
) async {
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null || profile.role != UserRole.admin) return false;
  return ref
      .read(firestoreServiceProvider)
      .getDailyMenu('default', date)
      .then((doc) => doc.exists && (doc.data()?['status'] == 'released'));
});

// Provides a real-time stream of released session maps for a given date.
// Guarded: only fires for admin users to prevent permission-denied.
final releasedSessionsProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, date) {
      final profileAsync = ref.watch(userProfileProvider);
      return profileAsync.when(
        data: (profile) {
          if (profile?.role != UserRole.admin) {
            return const Stream.empty();
          }
          return FirebaseFirestore.instance
              .collection('canteens')
              .doc('default')
              .collection('dailyMenus')
              .doc(date)
              .collection('sessions')
              .snapshots()
              .asyncMap((sessionsSnap) async {
                // Check top-level menu doc for released status
                final menuDoc = await FirebaseFirestore.instance
                    .collection('canteens')
                    .doc('default')
                    .collection('dailyMenus')
                    .doc(date)
                    .get();

                if (!menuDoc.exists || menuDoc.data()?['status'] != 'released') {
                  return <Map<String, dynamic>>[];
                }

                final now = DateTime.now();

                return sessionsSnap.docs.map((d) {
                  final data = d.data();
                  final startTime = data['startTime'] as String? ?? '';
                  final endTime = data['endTime'] as String? ?? '';

                  // Compute time state for this session using centralized logic
                  String timeState = 'upcoming';
                  final startDt = TimeHelper.parseSessionTime(startTime, now);
                  final endDt = TimeHelper.parseSessionTime(endTime, now);

                  if (startDt != null && endDt != null) {
                    if (now.isAfter(endDt)) {
                      timeState = 'ended';
                    } else if (!now.isBefore(startDt)) {
                      timeState = 'current';
                    }
                  }

                  return {
                    'sessionId': d.id,
                    'startTime': startTime,
                    'endTime': endTime,
                    'name': data['name'] ?? data['sessionNameSnapshot'] ?? d.id,
                    'timeState': timeState,
                    'isLive': timeState == 'current',
                    'slotInterval': data['slotInterval'] as int? ?? 15,
                    'slotCapacity': data['slotCapacity'] as int? ?? 20,
                  };
                }).toList();
              });
        },
        loading: () => const Stream.empty(),
        error: (e, s) => const Stream.empty(),
      );
    });

/// Stream of all canteen sessions, ordered by 'order'
/// Guarded: only fires for admin users.
final sessionsStreamProvider = StreamProvider<List<SessionModel>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile?.role != UserRole.admin) return const Stream.empty();
      final firestore = ref.watch(firestoreServiceProvider);
      return firestore.getSessionsStream('default').map((snapshot) {
        final sessions = snapshot.docs
            .map((doc) => SessionModel.fromFirestore(doc))
            .toList();
        
        final now = DateTime.now();
        // Sort chronologically by startTime
        sessions.sort((a, b) {
          final timeA = TimeHelper.parseSessionTime(a.startTime, now) ?? DateTime(2000);
          final timeB = TimeHelper.parseSessionTime(b.startTime, now) ?? DateTime(2000);
          return timeA.compareTo(timeB);
        });
        return sessions;
      });
    },
    loading: () => const Stream.empty(),
    error: (error, stackTrace) => const Stream.empty(),
  );
});

/// Stream of all menu categories, ordered by 'order'
/// Guarded: only fires for admin users.
final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile?.role != UserRole.admin) return const Stream.empty();
      final firestore = ref.watch(firestoreServiceProvider);
      return firestore.getCategoriesStream('default').map((snapshot) {
        return snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList();
      });
    },
    loading: () => const Stream.empty(),
    error: (e, s) => const Stream.empty(),
  );
});

/// Stream of all menu items, ordered by 'name'
/// Guarded: only fires for admin users.
final menuItemsStreamProvider = StreamProvider<List<MenuItemModel>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile?.role != UserRole.admin) return const Stream.empty();
      final firestore = ref.watch(firestoreServiceProvider);
      return firestore.getMenuItemsStream('default').map((snapshot) {
        return snapshot.docs
            .map((doc) => MenuItemModel.fromFirestore(doc))
            .toList();
      });
    },
    loading: () => const Stream.empty(),
    error: (e, s) => const Stream.empty(),
  );
});

/// Provides a list of items critically low in stock (< 5 remaining) for today
final criticalStockItemsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final releasedAsync = ref.watch(releasedSessionsProvider(dateStr));

  return releasedAsync.maybeWhen(
    data: (released) {
      List<Map<String, dynamic>> lowItems = [];
      for (var session in released) {
        final sessionId = session['sessionId'] as String;
        final itemsAsync = ref.watch(
          sessionItemsStreamProvider((date: dateStr, sessionId: sessionId)),
        );

        itemsAsync.whenData((snapshot) {
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final stock = (data['remainingStock'] ?? 0) as int;
            // Only alert if stock is positive but low.
            if (stock > 0 && stock <= 5) {
              lowItems.add({
                'name': data['nameSnapshot'] ?? 'Unknown Item',
                'stock': stock,
                'sessionId': sessionId,
              });
            }
          }
        });
      }
      return lowItems;
    },
    orElse: () => [],
  );
});

typedef DatePeriod = ({String start, String end});

/// Stream of orders for a specific period
final ordersByPeriodProvider =
    StreamProvider.family<List<DocumentSnapshot<Map<String, dynamic>>>, DatePeriod>((ref, period) {
      final profileAsync = ref.watch(userProfileProvider);

      return profileAsync.when(
        data: (profile) {
          if (profile?.role != UserRole.admin) {
            return Stream.value(<DocumentSnapshot<Map<String, dynamic>>>[]);
          }
          final firestore = ref.watch(firestoreServiceProvider);
          final startDate = DateFormat('yyyy-MM-dd').parse(period.start);
          final endDate = DateFormat('yyyy-MM-dd').parse(period.end);
          final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

          return firestore
              .getOrdersByDateRange('default', startOfDay, endOfDay)
              .map((snapshot) => snapshot.docs);
        },
        loading: () => const Stream.empty(),
        error: (e, s) {
          debugPrint('Error in ordersByDateProvider: $e');
          return Stream.value(<DocumentSnapshot<Map<String, dynamic>>>[]);
        },
      );
    });

/// Provides the daily menu document for a specific date
final dailyMenuProvider = StreamProvider.family<DocumentSnapshot<Map<String, dynamic>>, String>((ref, dateStr) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile?.role != UserRole.admin) return const Stream.empty();
      return FirebaseFirestore.instance
          .collection('canteens')
          .doc('default')
          .collection('dailyMenus')
          .doc(dateStr)
          .snapshots();
    },
    loading: () => const Stream.empty(),
    error: (_, _) => const Stream.empty(),
  );
});

/// Aggregate stats for the dashboard for a specific period
final statsByPeriodProvider = Provider.family<Map<String, dynamic>, DatePeriod>((ref, period) {
  final ordersAsync = ref.watch(ordersByPeriodProvider(period));
  final releasedSessionsAsync = ref.watch(releasedSessionsProvider(period.end));
  final allSessionsAsync = ref.watch(sessionsStreamProvider);
  final dailyMenuAsync = ref.watch(dailyMenuProvider(period.end));
  final categoriesAsync = ref.watch(categoriesStreamProvider);

  return ordersAsync.when(
    data: (orders) {
      double totalRevenue = 0;
      int totalItemsSold = 0;
      int activeTokens = 0;
      int calledTokens = 0;
      Map<String, double> categorySales = {};
      Map<String, Map<String, dynamic>> itemSales = {};
      Map<int, int> hourlyOrders = {};
      Map<int, double> hourlyRevenue = {};
      Map<int, int> hourlyUnits = {};
      Map<String, double> sessionSales = {};
      Map<String, Map<String, dynamic>> sessionStats = {};

      // Initialize all categories with 0.0
      final allCategories = categoriesAsync.valueOrNull ?? [];
      for (var cat in allCategories) {
        categorySales[cat.id] = 0.0;
      }

      // Initialize all active sessions with 0.0
      final allSessions = allSessionsAsync.valueOrNull ?? [];
      for (var session in allSessions.where((s) => s.isActive)) {
        sessionSales[session.name.toUpperCase()] = 0.0;
        sessionStats[session.name.toUpperCase()] = {'revenue': 0.0, 'orders': 0, 'units': 0};
      }

      for (var doc in orders) {
        final data = doc.data()!;
        final status = data['orderStatus'] ?? 'pending';
        final items = data['items'] as List? ?? [];
        final sessionName = (data['sessionNameSnapshot'] ?? data['sessionName'] ?? 'Unknown').toString().toUpperCase();
        
        final orderTotal = (data['totalAmount'] ?? 0).toDouble();
        totalRevenue += orderTotal;
        sessionSales[sessionName] = (sessionSales[sessionName] ?? 0) + orderTotal;
        
        for (var item in items) {
          final qty = (item['quantity'] ?? 1) as int;
          final price = (item['priceSnapshot'] ?? item['price'] ?? 0).toDouble();
          final subtotal = price * qty;
          totalItemsSold += qty;

          if (!sessionStats.containsKey(sessionName)) {
            sessionStats[sessionName] = {'revenue': 0.0, 'orders': 0, 'units': 0};
          }
          sessionStats[sessionName]!['revenue'] += subtotal;
          sessionStats[sessionName]!['units'] += qty;

          // Category aggregation
          final catId = item['categoryIdSnapshot'] ?? 'Other';
          categorySales[catId] = (categorySales[catId] ?? 0) + subtotal;

          // Item aggregation
          final itemName = item['nameSnapshot'] ?? 'Unknown';
          if (!itemSales.containsKey(itemName)) {
            itemSales[itemName] = {'name': itemName, 'session': sessionName, 'quantity': 0, 'revenue': 0.0};
          }
          itemSales[itemName]!['quantity'] += qty;
          itemSales[itemName]!['revenue'] += subtotal;
        }

        if (sessionStats.containsKey(sessionName)) {
          sessionStats[sessionName]!['orders'] += 1;
        }

        if (status == 'ready' || status == 'pending') {
          activeTokens++;
        }
        if (data['isCalledForPickup'] == true) {
          calledTokens++;
        }

        // Hourly Metrics
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final hour = createdAt.toDate().hour;
          hourlyOrders[hour] = (hourlyOrders[hour] ?? 0) + 1;
          hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) + orderTotal;
          
          for (var item in items) {
            final qty = (item['quantity'] ?? 1) as int;
            hourlyUnits[hour] = (hourlyUnits[hour] ?? 0) + qty;
          }
        }
      }

      final releasedSessions = releasedSessionsAsync.valueOrNull ?? [];
      final dailyMenuDoc = dailyMenuAsync.valueOrNull;
      final dailyMenuData = dailyMenuDoc?.data();

      return {
        'totalOrders': orders.length,
        'totalRevenue': totalRevenue,
        'totalItemsSold': totalItemsSold,
        'activeTokens': activeTokens,
        'calledTokens': calledTokens,
        'totalReleasedSessions': releasedSessions.length,
        'totalSessions': allSessions.where((s) => s.isActive).length,
        'totalUniqueItemsReleased': dailyMenuData?['totalUniqueItems'] ?? 0,
        'categorySales': categorySales,
        'itemSales': itemSales.values.toList()
          ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double)), // Sort by revenue instead of quantity
        'hourlyOrders': hourlyOrders,
        'hourlyRevenue': hourlyRevenue,
        'hourlyUnits': hourlyUnits,
        'sessionSales': sessionSales,
        'sessionStats': sessionStats,
      };
    },
    loading: () => {
      'totalOrders': 0,
      'totalRevenue': 0.0,
      'totalItemsSold': 0,
      'activeTokens': 0,
      'calledTokens': 0,
      'totalReleasedSessions': 0,
      'totalSessions': 0,
      'totalUniqueItemsReleased': 0,
      'categorySales': <String, double>{},
      'itemSales': <Map<String, dynamic>>[],
      'hourlyOrders': <int, int>{},
      'hourlyRevenue': <int, double>{},
      'hourlyUnits': <int, int>{},
      'sessionSales': <String, double>{},
      'sessionStats': <String, Map<String, dynamic>>{},
    },
    error: (_, _) => {
      'totalOrders': 0,
      'totalRevenue': 0.0,
      'totalItemsSold': 0,
      'activeTokens': 0,
      'totalReleasedSessions': 0,
      'totalSessions': 0,
      'totalUniqueItemsReleased': 0,
      'categorySales': <String, double>{},
      'itemSales': <Map<String, dynamic>>[],
      'hourlyOrders': <int, int>{},
      'hourlyRevenue': <int, double>{},
      'hourlyUnits': <int, int>{},
      'sessionSales': <String, double>{},
      'sessionStats': <String, Map<String, dynamic>>{},
    },
  );
});

/// Provides comparative stats between two periods
final comparativeStatsProvider = Provider.family<Map<String, String>, ({DatePeriod current, DatePeriod previous})>((ref, args) {
  final current = ref.watch(statsByPeriodProvider(args.current));
  final previous = ref.watch(statsByPeriodProvider(args.previous));

  String calcTrend(num cur, num prev) {
    if (prev == 0) return cur > 0 ? '+100%' : '0%';
    final pct = ((cur - prev) / prev * 100);
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}%';
  }

  return {
    'revenueTrend': calcTrend(current['totalRevenue'], previous['totalRevenue']),
    'ordersTrend': calcTrend(current['totalOrders'], previous['totalOrders']),
    'unitsSoldTrend': calcTrend(current['totalItemsSold'], previous['totalItemsSold']),
    'activeTokensTrend': calcTrend(current['activeTokens'], previous['activeTokens']),
    'calledTokensTrend': calcTrend(current['calledTokens'], previous['calledTokens']),
    'avgValueTrend': calcTrend(
      current['totalOrders'] > 0 ? current['totalRevenue'] / current['totalOrders'] : 0,
      previous['totalOrders'] > 0 ? previous['totalRevenue'] / previous['totalOrders'] : 0,
    ),
  };
});

/// Provides real-time stats for a specific session today
final sessionStatsProvider = StreamProvider.family<Map<String, int>, String>((
  ref,
  sessionId,
) {
  final profileAsync = ref.watch(userProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile?.role != UserRole.admin) {
        return Stream.value({'added': 0, 'stock': 0, 'sold': 0});
      }
      final firestore = ref.watch(firestoreServiceProvider);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      return firestore.getSessionItemsStream('default', today, sessionId).map((
        snapshot,
      ) {
        int added = 0;
        int stock = 0;
        int sold = 0;

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final initial = data['initialStock'] as int? ?? 0;
          final available = data['remainingStock'] as int? ?? 0;

          added += initial;
          stock += available;
          sold += (initial - available);
        }

        return {'added': added, 'stock': stock, 'sold': sold};
      });
    },
    loading: () => const Stream.empty(),
    error: (error, stackTrace) => Stream.value({'added': 0, 'stock': 0, 'sold': 0}),
  );
});

final sessionItemsStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, ({
      String date,
      String sessionId,
    })>((ref, arg) {
      final profileAsync = ref.watch(userProfileProvider);

      return profileAsync.when(
        data: (profile) {
          if (profile?.role != UserRole.admin) {
            // Return a stream that emits an empty snapshot or just never emits if not admin
            // For now, returning empty is safer to avoid UI getting stuck if it depends on it
            return Stream.empty();
          }
          final firestore = ref.watch(firestoreServiceProvider);
          return firestore.getSessionItemsStream(
            'default',
            arg.date,
            arg.sessionId,
          );
        },
        loading: () => const Stream.empty(),
        error: (error, stackTrace) => const Stream.empty(),
      );
    });

final sessionSlotsStreamProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, ({
      String date,
      String sessionId,
    })>((ref, arg) {
      final profileAsync = ref.watch(userProfileProvider);

      return profileAsync.when(
        data: (profile) {
          if (profile?.role != UserRole.admin) {
            return Stream.empty();
          }
          return FirebaseFirestore.instance
              .collection('canteens')
              .doc('default')
              .collection('dailyMenus')
              .doc(arg.date)
              .collection('sessions')
              .doc(arg.sessionId)
              .collection('slots')
              .snapshots();
        },
        loading: () => const Stream.empty(),
        error: (error, stackTrace) => const Stream.empty(),
      );
    });

/// Weekly Traffic Provider for radar chart
final weeklyTrafficProvider = StreamProvider<Map<String, Map<String, Map<String, int>>>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.when(
    data: (profile) {
      if (profile?.role != UserRole.admin) return const Stream.empty();
      final firestore = ref.watch(firestoreServiceProvider);
      
      final now = DateTime.now();
      // start of day 13 days ago (total 14 days including today)
      final startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 13));
      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      return firestore.getOrdersByDateRange('default', startDate, endDate).map((snapshot) {
        // days 0..6 is This Week, 7..13 is Last Week
        // Mon = 1 ... Sun = 7
        final traffic = {
          'This Week': {
             for (var i = 1; i <= 7; i++) i.toString(): {'new': 0, 'repeat': 0}
          },
          'Last Week': {
             for (var i = 1; i <= 7; i++) i.toString(): {'new': 0, 'repeat': 0}
          }
        };

        Set<String> seenUids = {};
        
        // Go from oldest to newest to track new vs repeat accurately for the window
        final docs = snapshot.docs.reversed.toList();
        
        for (var doc in docs) {
          final data = doc.data();
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt == null) continue;
          final dt = createdAt.toDate();
          final uid = data['userId'] as String? ?? 'unknown';
          
          bool isNew = !seenUids.contains(uid);
          seenUids.add(uid);
          
          final dayDiff = DateTime(now.year, now.month, now.day).difference(DateTime(dt.year, dt.month, dt.day)).inDays;
          
          if (dayDiff < 0 || dayDiff > 13) continue;
          
          final weekKey = dayDiff <= 6 ? 'This Week' : 'Last Week';
          final weekday = dt.weekday.toString();
          
          if (isNew) {
            traffic[weekKey]![weekday]!['new'] = (traffic[weekKey]![weekday]!['new'] ?? 0) + 1;
          } else {
            traffic[weekKey]![weekday]!['repeat'] = (traffic[weekKey]![weekday]!['repeat'] ?? 0) + 1;
          }
        }
        
        return traffic;
      });
    },
    loading: () => const Stream.empty(),
    error: (e, s) => const Stream.empty(),
  );
});
