import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Collection References ────────────────────────────────────────────

  /// Toplevel collections
  CollectionReference<Map<String, dynamic>> get canteensCollection =>
      _db.collection('canteens');

  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _db.collection('users');

  /// Subcollections of 'canteens/default'
  CollectionReference<Map<String, dynamic>> sessionsCollection(
    String canteenId,
  ) => canteensCollection.doc(canteenId).collection('sessions');

  CollectionReference<Map<String, dynamic>> categoriesCollection(
    String canteenId,
  ) => canteensCollection.doc(canteenId).collection('categories');

  CollectionReference<Map<String, dynamic>> menuItemsCollection(
    String canteenId,
  ) => canteensCollection.doc(canteenId).collection('menuItems');

  CollectionReference<Map<String, dynamic>> ordersCollection(
    String canteenId,
  ) => canteensCollection.doc(canteenId).collection('orders');

  CollectionReference<Map<String, dynamic>> dailyMenusCollection(
    String canteenId,
  ) => canteensCollection.doc(canteenId).collection('dailyMenus');

  DocumentReference<Map<String, dynamic>> slotDefaultsRef(String canteenId) =>
      canteensCollection
          .doc(canteenId)
          .collection('slotDefaults')
          .doc('config');

  // ── Auth & Profile ───────────────────────────────────────────────────

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserProfile(
    String uid,
  ) async {
    return await usersCollection.doc(uid).get();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserProfile(String uid) {
    return usersCollection.doc(uid).snapshots();
  }

  Future<void> setUserProfile(String uid, Map<String, dynamic> data) async {
    await usersCollection.doc(uid).set(data, SetOptions(merge: true));
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await usersCollection.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Image Upload ───────────────────────────────────────────────────

  Future<String> uploadMenuItemImage(File file, String canteenId) async {
    final fileName =
        'items/${DateTime.now().millisecondsSinceEpoch}_${file.path.split(Platform.pathSeparator).last}';
    final ref = FirebaseStorage.instance
        .ref()
        .child('canteens')
        .child(canteenId)
        .child(fileName);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<String> uploadProfileImage(File file, String uid) async {
    final fileName = 'profiles/$uid/avatar.jpg';
    final ref = FirebaseStorage.instance.ref().child(fileName);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  // ── Canteen Management ───────────────────────────────────────────────

  Future<DocumentSnapshot<Map<String, dynamic>>> getCanteen(String id) async {
    return await canteensCollection.doc(id).get();
  }

  Future<void> updateCanteen(String id, Map<String, dynamic> data) async {
    await canteensCollection.doc(id).set(data, SetOptions(merge: true));
  }

  // ── Session Management ───────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> getSessionsStream(
    String canteenId,
  ) {
    return sessionsCollection(canteenId).orderBy('order').snapshots();
  }

  Future<void> saveSession(
    String canteenId,
    String? id,
    Map<String, dynamic> data,
  ) async {
    // Ensure default fields are present
    final normalized = {
      'defaultInterval': data['defaultInterval'],
      'defaultCapacity': data['defaultCapacity'],
      'customSlots': data['customSlots'] ?? [],
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      normalized['createdAt'] = FieldValue.serverTimestamp();
      await sessionsCollection(canteenId).add(normalized);
    } else {
      await sessionsCollection(canteenId).doc(id).update(normalized);
    }
  }

  Future<void> deleteSession(String canteenId, String id) async {
    await sessionsCollection(canteenId).doc(id).delete();
  }

  // ── Category Management ──────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> getCategoriesStream(
    String canteenId,
  ) {
    return categoriesCollection(canteenId).orderBy('order').snapshots();
  }

  Future<void> saveCategory(
    String canteenId,
    String? id,
    Map<String, dynamic> data,
  ) async {
    final normalized = {
      'isActive': true,
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      normalized['createdAt'] = FieldValue.serverTimestamp();
      await categoriesCollection(canteenId).add(normalized);
    } else {
      await categoriesCollection(canteenId).doc(id).update(normalized);
    }
  }

  Future<void> deleteCategory(String canteenId, String id) async {
    await categoriesCollection(canteenId).doc(id).delete();
  }

  // ── Menu Management ─────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> getMenuItemsStream(
    String canteenId,
  ) {
    return menuItemsCollection(canteenId).orderBy('name').snapshots();
  }

  Future<void> saveMenuItem(
    String canteenId,
    String? id,
    Map<String, dynamic> data,
  ) async {
    final normalized = {
      'description': '',
      'imageUrl': '',
      'isAvailable': true,
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (id == null) {
      normalized['createdAt'] = FieldValue.serverTimestamp();
      await menuItemsCollection(canteenId).add(normalized);
    } else {
      await menuItemsCollection(canteenId).doc(id).update(normalized);
    }
  }

  Future<void> deleteMenuItem(String canteenId, String id) async {
    await menuItemsCollection(canteenId).doc(id).delete();
  }

  // ── Slot Defaults ───────────────────────────────────────────────────

  Future<DocumentSnapshot<Map<String, dynamic>>> getSlotDefaults(
    String canteenId,
  ) async {
    return await slotDefaultsRef(canteenId).get();
  }

  Future<void> saveSlotDefaults(
    String canteenId,
    Map<String, dynamic> data,
  ) async {
    await slotDefaultsRef(canteenId).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Release Menu Flow ───────────────────────────────────────────────

  Future<DocumentSnapshot<Map<String, dynamic>>> getDailyMenu(
    String canteenId,
    String date,
  ) async {
    return await dailyMenusCollection(canteenId).doc(date).get();
  }

  /// Atomic Menu Release using WriteBatch
  Future<void> releaseDailyMenu({
    required String canteenId,
    required String date,
    required Map<String, dynamic> menuData,
    required List<Map<String, dynamic>>
    sessions, // Contains sessions with items and slots
    String? createdByUid,
  }) async {
    final batch = _db.batch();
    final menuDocRef = dailyMenusCollection(canteenId).doc(date);

    // 1. Root dailyMenu doc — full fields
    batch.set(menuDocRef, {
      ...menuData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      // ignore: use_null_aware_elements
      if (createdByUid != null) 'createdBy': createdByUid,
      'selectedSessionIds': sessions.map((s) => s['sessionId']).toList(),
    });

    // 2. Individual sessions
    for (final session in sessions) {
      final sessionId = session['sessionId'] as String;
      final sessionRef = menuDocRef.collection('sessions').doc(sessionId);

      final items = List<Map<String, dynamic>>.from(session['items'] ?? []);
      final slots = List<Map<String, dynamic>>.from(session['slots'] ?? []);

      // Session doc — full normalized fields
      batch.set(sessionRef, {
        'sessionId': sessionId,
        'sessionNameSnapshot': session['name'] ?? '',
        'startTime': session['startTime'] ?? '',
        'endTime': session['endTime'] ?? '',
        'slotInterval': session['slotInterval'] ?? session['defaultInterval'],
        'slotCapacity': session['slotCapacity'] ?? session['defaultCapacity'],
        'releaseDate': date,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Session Items — full snapshot fields
      for (final item in items) {
        final itemId = item['id'] ?? item['menuItemId'];
        final itemRef = sessionRef.collection('items').doc(itemId);
        batch.set(itemRef, {
          'itemId': itemId,
          'nameSnapshot': item['name'] ?? item['nameSnapshot'] ?? '',
          'priceSnapshot': item['price'] ?? item['priceSnapshot'] ?? 0,
          'categoryIdSnapshot':
              item['categoryId'] ?? item['categoryIdSnapshot'] ?? '',
          'categoryIdsSnapshot':
              item['categoryIds'] ?? item['categoryIdsSnapshot'] ?? [],
          'imageUrlSnapshot':
              item['imageUrl'] ?? item['imageUrlSnapshot'] ?? '',
          'descriptionSnapshot':
              item['description'] ?? item['descriptionSnapshot'] ?? '',
          'isAvailableSnapshot':
              item['isAvailable'] ?? item['isAvailableSnapshot'] ?? true,
          'initialStock': item['initialStock'] ?? item['stock'] ?? 0,
          'remainingStock':
              item['remainingStock'] ??
              item['availableStock'] ??
              item['initialStock'] ??
              item['stock'] ??
              0,
          'isPreReady': item['isPreReady'] ?? false,
        }, SetOptions(merge: true));
      }

      // 4. Session Slots — full normalized fields
      for (final slot in slots) {
        final slotId =
            slot['id'] ?? slot['startTime'].toString().replaceAll(':', '');
        final slotRef = sessionRef.collection('slots').doc(slotId);
        batch.set(slotRef, {
          'startTime': slot['startTime'] ?? '',
          'endTime': slot['endTime'] ?? '',
          'capacity': slot['capacity'] ?? 0,
          'remainingCapacity':
              slot['remainingCapacity'] ?? slot['capacity'] ?? 0,
          'isSelected': slot['isSelected'] ?? true,
          'isEnabled': slot['isEnabled'] ?? true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getSessionItemsStream(
    String canteenId,
    String date,
    String sessionId,
  ) {
    return dailyMenusCollection(canteenId)
        .doc(date)
        .collection('sessions')
        .doc(sessionId)
        .collection('items')
        .snapshots();
  }

  // ── Orders ───────────────────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> getOrdersStream(
    String canteenId,
  ) {
    return ordersCollection(
      canteenId,
    ).orderBy('createdAt', descending: true).snapshots();
  }

  Future<void> updateOrderStatus(
    String canteenId,
    String orderId,
    String status,
  ) async {
    await ordersCollection(canteenId).doc(orderId).update({
      'orderStatus': status,
      'statusCategory': status,
      'activeForStaff': (status != 'served' && status != 'cancelled'),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> callTokenForPickup(
    String canteenId,
    String orderId,
  ) async {
    await ordersCollection(canteenId).doc(orderId).update({
      'isCalledForPickup': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateOrderItemStatus(
    String canteenId,
    String orderId,
    int itemIndex,
    String newStatus,
  ) async {
    final orderRef = ordersCollection(canteenId).doc(orderId);
    final orderDoc = await orderRef.get();
    if (!orderDoc.exists) return;

    final items = List<Map<String, dynamic>>.from(
      orderDoc.data()?['items'] ?? [],
    );
    if (itemIndex >= items.length) return;

    items[itemIndex]['itemStatus'] = newStatus;

    // Check if all items are served
    bool allServed = true;
    bool anyReady = false;
    for (var it in items) {
      final s = it['itemStatus']?.toString().toLowerCase();
      if (s != 'served') allServed = false;
      if (s == 'ready') anyReady = true;
    }

    String orderStatus = 'pending';
    if (allServed) {
      orderStatus = 'served';
    } else if (anyReady) {
      orderStatus = 'ready';
    } else if (items.any(
      (it) => it['itemStatus']?.toString().toLowerCase() == 'served',
    )) {
      orderStatus = 'partial served';
    }

    await orderRef.update({
      'items': items,
      'orderStatus': orderStatus,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Date-filtered Orders ──────────────────────────────────────────────

  Stream<QuerySnapshot<Map<String, dynamic>>> getOrdersByOrderDate(
    String canteenId,
    String date,
  ) {
    return ordersCollection(canteenId)
        .where('orderDate', isEqualTo: date)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getOrdersByDateRange(
    String canteenId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return ordersCollection(canteenId)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> carryOverStock({
    required String canteenId,
    required String date,
    required String fromSessionId,
    required String toSessionId,
    required List<Map<String, dynamic>> itemsToCarry,
  }) async {
    final batch = _db.batch();
    final menuDoc = dailyMenusCollection(canteenId).doc(date);

    for (var item in itemsToCarry) {
      final itemId = item['itemId'];
      final stockToCarry = item['stock'] ?? 0;

      if (stockToCarry <= 0) continue;

      final fromItemRef = menuDoc
          .collection('sessions')
          .doc(fromSessionId)
          .collection('items')
          .doc(itemId);

      final toItemRef = menuDoc
          .collection('sessions')
          .doc(toSessionId)
          .collection('items')
          .doc(itemId);

      // 1. Decrement source session stock to 0 (since it moved)
      batch.update(fromItemRef, {
        'remainingStock': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Increment target session stock and sync full fields to ensure visibility
      batch.set(
        toItemRef,
        {
          'itemId': itemId,
          'nameSnapshot': item['name'] ?? '',
          'priceSnapshot': item['price'] ?? 0,
          'categoryIdSnapshot': item['categoryId'] ?? 'Other',
          'categoryIdsSnapshot': item['categoryIds'] ?? [item['categoryId'] ?? 'Other'],
          'imageUrlSnapshot': item['imageUrl'] ?? '',
          'descriptionSnapshot': item['description'] ?? '',
          'isPreReady': item['isPreReady'] ?? false,
          'isAvailableSnapshot': true, // Always available if carried over
          'remainingStock': FieldValue.increment(stockToCarry),
          'initialStock': FieldValue.increment(stockToCarry),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  /// Automatically moves stock for items marked as 'isPreReady' from an ended
  /// session to the next released session of the day.
  Future<int> autoCarryOverPreReadyItems({
    required String canteenId,
    required String date,
    required String fromSessionId,
    required String toSessionId,
  }) async {
    final menuDoc = dailyMenusCollection(canteenId).doc(date);
    
    // Get pre-ready items with stock from source session
    final sourceItemsSnap = await menuDoc
        .collection('sessions')
        .doc(fromSessionId)
        .collection('items')
        .where('isPreReady', isEqualTo: true)
        .get();

    if (sourceItemsSnap.docs.isEmpty) return 0;

    final batch = _db.batch();
    int carriedCount = 0;

    for (var doc in sourceItemsSnap.docs) {
      final data = doc.data();
      final stock = (data['remainingStock'] ?? 0) as int;
      
      if (stock > 0) {
        final itemId = doc.id;
        final toItemRef = menuDoc
            .collection('sessions')
            .doc(toSessionId)
            .collection('items')
            .doc(itemId);

        // Move stock to target
        batch.set(toItemRef, {
          'remainingStock': FieldValue.increment(stock),
          'initialStock': FieldValue.increment(stock),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Optional: Drain source stock to avoid double counting if multiple checks run
        batch.update(doc.reference, {
          'remainingStock': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        carriedCount++;
      }
    }

    if (carriedCount > 0) {
      await batch.commit();
    }
    return carriedCount;
  }

  Future<void> updateReleasedItemStock({
    required String canteenId,
    required String date,
    required String sessionId,
    required String itemId,
    required int delta,
  }) async {
    final itemRef = dailyMenusCollection(canteenId)
        .doc(date)
        .collection('sessions')
        .doc(sessionId)
        .collection('items')
        .doc(itemId);

    await itemRef.update({
      'initialStock': FieldValue.increment(delta),
      'remainingStock': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateReleasedSlotCapacity({
    required String canteenId,
    required String date,
    required String sessionId,
    required String slotId,
    required int delta,
  }) async {
    final slotRef = dailyMenusCollection(canteenId)
        .doc(date)
        .collection('sessions')
        .doc(sessionId)
        .collection('slots')
        .doc(slotId);

    await slotRef.update({
      'capacity': FieldValue.increment(delta),
      'remainingCapacity': FieldValue.increment(delta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
