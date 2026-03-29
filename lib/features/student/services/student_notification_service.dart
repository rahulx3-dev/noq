import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../../core/providers.dart';

class StudentNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Public method to add a notification from external services (like the alert provider)
  Future<void> addNotification({
    required String title,
    required String body,
    required String type,
    String? orderId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _persistNotification(
      uid: user.uid,
      title: title,
      body: body,
      type: type,
      orderId: orderId,
    );
  }

  // Method to persist notification to Firestore history
  Future<void> _persistNotification({
    required String uid,
    required String title,
    required String body,
    required String type,
    String? orderId,
  }) async {
    try {
      await _db.collection('users').doc(uid).collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      debugPrint('Error persisting notification: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> watchHistoricalNotifications() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> readAll() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final query = await _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();
        
    final batch = _db.batch();
    for (var doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> clearAll() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final query = await _db
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .get();
        
    final batch = _db.batch();
    for (var doc in query.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final studentNotificationServiceProvider = Provider(
  (ref) => StudentNotificationService(),
);

final unreadNotificationsCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('notifications')
      .where('isRead', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
});

final historicalNotificationsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final service = ref.watch(studentNotificationServiceProvider);
      return service.watchHistoricalNotifications();
    });
