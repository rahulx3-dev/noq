import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/admin_notification_model.dart';

class AdminNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _canteenId = 'default';

  Stream<List<AdminNotification>> watchNotifications() {
    return _db
        .collection('canteens')
        .doc(_canteenId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AdminNotification.fromFirestore(doc)).toList());
  }

  Future<void> addNotification(AdminNotification notification) async {
    try {
      await _db
          .collection('canteens')
          .doc(_canteenId)
          .collection('notifications')
          .add(notification.toMap());
    } catch (e) {
      // Log error but don't crash the app
      print('Firestore Notification Error: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await _db
        .collection('canteens')
        .doc(_canteenId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final unread = await _db
        .collection('canteens')
        .doc(_canteenId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _db.batch();
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> clearAll() async {
    final all = await _db
        .collection('canteens')
        .doc(_canteenId)
        .collection('notifications')
        .get();

    final batch = _db.batch();
    for (var doc in all.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

final adminNotificationServiceProvider = Provider((ref) => AdminNotificationService());

final adminNotificationsStreamProvider =
    StreamProvider<List<AdminNotification>>((ref) {
      return ref.watch(adminNotificationServiceProvider).watchNotifications();
    });

final unreadAdminNotificationsCountProvider = Provider<int>((ref) {
  // Use valueOrNull — never throws even if provider is in error/loading state.
  final notifications =
      ref.watch(adminNotificationsStreamProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isRead).length;
});
