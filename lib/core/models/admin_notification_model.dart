import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminNotificationType {
  reminder,
  alert,
  success,
  action,
}

class AdminNotification {
  final String id;
  final String title;
  final String body;
  final AdminNotificationType type;
  final DateTime timestamp;
  final String? sessionId;
  final String? actionType; // e.g., 'release', 'carry_over'
  final bool isRead;
  final Map<String, dynamic>? metadata;

  AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.sessionId,
    this.actionType,
    this.isRead = false,
    this.metadata,
  });

  factory AdminNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: AdminNotificationType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'alert'),
        orElse: () => AdminNotificationType.alert,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sessionId: data['sessionId'],
      actionType: data['actionType'],
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'sessionId': sessionId,
      'actionType': actionType,
      'isRead': isRead,
      'metadata': metadata,
    };
  }
}
