import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../providers/student_cart_provider.dart';

class StudentOrderService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String _canteenId = 'default';

  StudentOrderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Placeholder removed: _generateTokenNumber logic moved inside processCheckout to avoid unauthorized reads.

  /// Processes a checkout. Items are grouped by (sessionId + slotId).
  /// Each group becomes one order document. All orders share a checkoutGroupId.
  ///
  /// RULE: Each cart item MUST have a selectedSlot set before calling this.
  /// Two items from the same session with different slots produce separate orders.
  Future<String> processCheckout({
    required String date,
    required List<StudentCartItem> cartItems,
    required double baseTax,
    required double platformFee,
    required double totalSubtotal,
    required String studentName,
    required String studentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Validate all items have slots
    for (var c in cartItems) {
      if (c.selectedSlot == null) {
        throw Exception('Item ${c.menuItem.nameSnapshot} has no slot selected');
      }
    }

    // Group items by composite key: sessionId + slotId
    final orderGroups = <String, List<StudentCartItem>>{};
    for (var c in cartItems) {
      final key = '${c.menuItem.sessionId}__${c.selectedSlot!.id}';
      orderGroups.putIfAbsent(key, () => []).add(c);
    }

    final checkoutGroupId = const Uuid().v4();
    final checkoutCreatedAt = FieldValue.serverTimestamp();

    await _db.runTransaction((transaction) async {
      final rootDoc = _db
          .collection('canteens')
          .doc(_canteenId)
          .collection('dailyMenus')
          .doc(date);

      // ── 0. Collect all unique slot and item refs we need to read ──
      final slotRefs = <String, DocumentReference>{}; // key = slotId
      final itemRefs = <String, DocumentReference>{}; // key = itemId
      
      final virtualSlotIds = <String>{};

      for (var c in cartItems) {
        final sId = c.menuItem.sessionId;
        final slotId = c.selectedSlot!.id;
        
        // Identify virtual slots (e.g. from between-session fallbacks)
        final isVirtual = slotId.toLowerCase().startsWith('virtual_') || 
                         slotId.toLowerCase().startsWith('immediate_') ||
                         slotId.toLowerCase().startsWith('soon_');
        
        if (isVirtual) {
          virtualSlotIds.add(slotId);
        } else {
          slotRefs.putIfAbsent(
            slotId,
            () => rootDoc
                .collection('sessions')
                .doc(sId)
                .collection('slots')
                .doc(slotId),
          );
        }

        itemRefs.putIfAbsent(
          c.menuItem.itemId,
          () => rootDoc
              .collection('sessions')
              .doc(sId)
              .collection('items')
              .doc(c.menuItem.itemId),
        );
      }

      final counterRef = _db
          .collection('canteens')
          .doc(_canteenId)
          .collection('counters')
          .doc('dailyToken')
          .collection('days')
          .doc(date);

      // ── 1. ALL READS FIRST ──
      final counterSnap = await transaction.get(counterRef);

      final slotSnapshots = <String, DocumentSnapshot>{};
      for (var entry in slotRefs.entries) {
        slotSnapshots[entry.key] = await transaction.get(entry.value);
      }

      final itemSnapshots = <String, DocumentSnapshot>{};
      for (var entry in itemRefs.entries) {
        itemSnapshots[entry.key] = await transaction.get(entry.value);
      }

      // Read category docs to check isReadyMade
      final categoryIds = cartItems
          .map((c) => c.menuItem.categoryIdSnapshot)
          .toSet();
      final categoryReadyMade = <String, bool>{};
      for (var catId in categoryIds) {
        if (catId.isEmpty) continue;
        final catDoc = await transaction.get(
          _db
              .collection('canteens')
              .doc(_canteenId)
              .collection('categories')
              .doc(catId),
        );
        if (catDoc.exists) {
          final catData = catDoc.data() ?? {};
          categoryReadyMade[catId] = catData['isPreReady'] ?? catData['isReadyMade'] ?? false;
        }
      }

      // 2. CALCULATIONS & VALIDATIONS
      final int currentTokenCounter = (counterSnap.data()?['lastTokenNumber'] ?? 0) + 1;
      final bool counterExists = counterSnap.exists;
      final String tokenNumberString = currentTokenCounter.toString();

      // Validate stock
      for (var c in cartItems) {
        final itemSnap = itemSnapshots[c.menuItem.itemId]!;
        if (!itemSnap.exists) {
          // If the item doesn't exist in the daily release (e.g. session not released yet), 
          // allow it to pass if it's a pre-ready item.
          if (c.menuItem.isPreReady) continue;
          
          throw Exception(
            'Item ${c.menuItem.nameSnapshot} not found in the released menu.',
          );
        }
        final data = itemSnap.data() as Map<String, dynamic>? ?? {};
        final currentStock = data['remainingStock'] ?? 0;
        if (currentStock < c.quantity) {
          throw Exception(
            'Not enough stock for ${c.menuItem.nameSnapshot} (need ${c.quantity}, have $currentStock)',
          );
        }
      }

      // Validate capacity
      final usedSlotIds = cartItems.map((c) => c.selectedSlot!.id).toSet();
      final slotDemand = <String, int>{};
      for (var slotId in usedSlotIds) {
        if (virtualSlotIds.contains(slotId)) continue;
        slotDemand[slotId] = 1; // 1 booking per slot
      }
      for (var entry in slotDemand.entries) {
        final slotSnap = slotSnapshots[entry.key];
        if (slotSnap == null || !slotSnap.exists) {
          throw Exception('The selected pickup slot is no longer available.');
        }
        final data = slotSnap.data() as Map<String, dynamic>? ?? {};
        final currentCap = data['remainingCapacity'] ?? 0;
        if (currentCap < entry.value) {
          final st = data['startTime'] ?? entry.key;
          throw Exception(
            'Slot $st is full. Please select a different time.',
          );
        }
      }

      // 3. WRITE ACTIONS: Counter update will happen at the end

      // Decrement stock (only for items that exist in the daily menu)
      for (var c in cartItems) {
        final itemRef = itemRefs[c.menuItem.itemId];
        final itemSnap = itemSnapshots[c.menuItem.itemId];
        if (itemRef != null && (itemSnap?.exists ?? false)) {
          transaction.update(itemRef, {
            'remainingStock': FieldValue.increment(-c.quantity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Decrement capacity (only for non-virtual slots)
      for (var entry in slotDemand.entries) {
        final ref = slotRefs[entry.key];
        if (ref != null) {
          transaction.update(ref, {
            'remainingCapacity': FieldValue.increment(-entry.value),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // 7. Create one order document per (sessionId + slotId) group
      for (var groupEntry in orderGroups.entries) {
        
        final groupItems = groupEntry.value;
        final firstItem = groupItems.first;
        final sId = firstItem.menuItem.sessionId;
        final slot = firstItem.selectedSlot!;

        final groupSubtotal = groupItems.fold(
          0.0,
          (acc, c) => acc + (c.menuItem.priceSnapshot * c.quantity),
        );
        final ratio = totalSubtotal > 0 ? (groupSubtotal / totalSubtotal) : 0.0;
        final groupTax = baseTax * ratio;
        final groupPlatformFee = platformFee * ratio;
        final groupTotal = groupSubtotal + groupTax + groupPlatformFee;

        final orderRef = _db
            .collection('canteens')
            .doc(_canteenId)
            .collection('orders')
            .doc();

        final itemsData = groupItems.map((c) {
          final isReady =
              c.menuItem.isPreReady || (categoryReadyMade[c.menuItem.categoryIdSnapshot] ?? false);
          return {
            'itemId': c.menuItem.itemId,
            'nameSnapshot': c.menuItem.nameSnapshot,
            'priceSnapshot': c.menuItem.priceSnapshot,
            'imageUrlSnapshot': c.menuItem.imageUrlSnapshot,
            'categoryIdSnapshot': c.menuItem.categoryIdSnapshot,
            'descriptionSnapshot': c.menuItem.descriptionSnapshot,
            'quantity': c.quantity,
            'itemStatus': isReady ? 'ready' : 'pending',
            'isPreReady': isReady,
            'sessionId': sId,
            'selectedSlotId': c.selectedSlot!.id,
            'selectedSlotStartTime': c.selectedSlot!.startTime,
            'selectedSlotEndTime': c.selectedSlot!.endTime,
          };
        }).toList();

        final int totalItemsQty = groupItems.fold(
          0,
          (acc, c) => acc + c.quantity,
        );
        final int readyItemsQty = groupItems.fold(0, (acc, c) {
          final isReady =
              c.menuItem.isPreReady || (categoryReadyMade[c.menuItem.categoryIdSnapshot] ?? false);
          return acc + (isReady ? c.quantity : 0);
        });
        final int pendingItemsQty = totalItemsQty - readyItemsQty;
        final String initialOrderStatus = 'pending';

        transaction.set(orderRef, {
          'orderId': orderRef.id,
          'checkoutGroupId': checkoutGroupId,
          'checkoutCreatedAt': checkoutCreatedAt,
          'tokenNumber': tokenNumberString,
          'studentUid': user.uid,
          'studentName': studentName,
          'studentId': studentId,
          'sessionId': sId,
          'sessionNameSnapshot': groupItems.first.menuItem.sessionNameSnapshot,
          'slotId': slot.id,
          'slotStartTime': slot.startTime,
          'slotEndTime': slot.endTime,

          // Order Statuses
          'orderStatus': initialOrderStatus,
          'statusCategory': initialOrderStatus,
          'hasPartialItems': readyItemsQty > 0 && pendingItemsQty > 0,

          // Staff Operational Counts
          'totalItemCount': totalItemsQty,
          'pendingItemCount': pendingItemsQty,
          'readyItemCount': readyItemsQty,
          'servedItemCount': 0,
          'skippedItemCount': 0,
          'activeForStaff': true,
          'isCalledForPickup': false,
          'orderDate': date,

          // Payment & Totals
          'paymentStatus': 'paid',
          'paymentMode': 'upi',
          'transactionId': 'MOCK_UPI_${DateTime.now().millisecondsSinceEpoch}',
          'subtotal': groupSubtotal,
          'taxAmount': groupTax,
          'platformFee': groupPlatformFee,
          'totalAmount': groupTotal,

          // Timestamps & Items
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'items': itemsData,
        });
      }

      // Update counter once at the end with final value
      if (counterExists) {
        transaction.update(counterRef, {
          'lastTokenNumber': currentTokenCounter,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(counterRef, {
          'date': date,
          'lastTokenNumber': currentTokenCounter,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    // Add 'Order Placed' notification after successful transaction
    try {
      final notificationRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc();
      await notificationRef.set({
        'title': 'Order Placed Successfully',
        'body':
            'Your order has been placed. You can track it in the Orders section.',
        'type': 'success',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'checkoutGroupId': checkoutGroupId,
      });
    } catch (e) {
      // Silently fail or log, don't break checkout success
      debugPrint('Error persisting checkout notification: $e');
    }

    return checkoutGroupId;
  }

  /// Marks a list of checkout groups as hidden for the student.
  /// This removes them from the student's order history UI.
  Future<void> hideCheckoutGroups(List<String> checkoutGroupIds) async {
    if (checkoutGroupIds.isEmpty) return;
    
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Chunk because of whereIn limit (30)
    for (var i = 0; i < checkoutGroupIds.length; i += 10) {
      final chunk = checkoutGroupIds.sublist(
        i,
        (i + 10) > checkoutGroupIds.length ? checkoutGroupIds.length : (i + 10),
      );

      final query = await _db
          .collection('canteens')
          .doc(_canteenId)
          .collection('orders')
          .where('studentUid', isEqualTo: user.uid)
          .where('checkoutGroupId', whereIn: chunk)
          .get();

      if (query.docs.isEmpty) continue;

      final batch = _db.batch();
      for (var doc in query.docs) {
        batch.update(doc.reference, {
          'isHiddenByStudent': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }
}
