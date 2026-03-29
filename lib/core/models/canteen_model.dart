import 'package:cloud_firestore/cloud_firestore.dart';

class CanteenModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String phone;
  final String email;
  final String address;
  final String openTime;
  final String closeTime;
  final bool isOpenToday;
  final DateTime updatedAt;

  CanteenModel({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.phone,
    required this.email,
    required this.address,
    required this.openTime,
    required this.closeTime,
    required this.isOpenToday,
    required this.updatedAt,
  });

  factory CanteenModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CanteenModel(
      id: doc.id,
      name: data['name'] ?? '',
      logoUrl: data['logoUrl'],
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      openTime: data['openTime'] ?? '08:00',
      closeTime: data['closeTime'] ?? '20:00',
      isOpenToday: data['isOpenToday'] ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'phone': phone,
      'email': email,
      'address': address,
      'openTime': openTime,
      'closeTime': closeTime,
      'isOpenToday': isOpenToday,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
