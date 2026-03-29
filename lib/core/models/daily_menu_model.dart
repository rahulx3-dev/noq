import 'package:cloud_firestore/cloud_firestore.dart';

enum DailyMenuStatus { draft, released, archived }

class DailyMenuModel {
  final String date; // Format: yyyy-MM-dd
  final DailyMenuStatus status;
  final int totalCapacity;
  final int slotsAllocated;
  final DateTime updatedAt;

  DailyMenuModel({
    required this.date,
    required this.status,
    required this.totalCapacity,
    required this.slotsAllocated,
    required this.updatedAt,
  });

  factory DailyMenuModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyMenuModel(
      date: doc.id,
      status: _parseStatus(data['status']),
      totalCapacity: data['totalCapacity'] ?? 0,
      slotsAllocated: data['slotsAllocated'] ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      'totalCapacity': totalCapacity,
      'slotsAllocated': slotsAllocated,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DailyMenuStatus _parseStatus(String? status) {
    return DailyMenuStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => DailyMenuStatus.draft,
    );
  }
}

class DailyItemModel {
  final String menuItemId;
  final String name;
  final double price;
  final int stock;
  final int soldQuantity;

  DailyItemModel({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.stock,
    required this.soldQuantity,
  });

  factory DailyItemModel.fromMap(Map<String, dynamic> data) {
    return DailyItemModel(
      menuItemId: data['menuItemId'] ?? '',
      name: data['name'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      stock: data['stock'] ?? 0,
      soldQuantity: data['soldQuantity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menuItemId': menuItemId,
      'name': name,
      'price': price,
      'stock': stock,
      'soldQuantity': soldQuantity,
    };
  }
}

class DailySessionModel {
  final String sessionId;
  final String sessionName;
  final List<DailyItemModel> items;

  DailySessionModel({
    required this.sessionId,
    required this.sessionName,
    required this.items,
  });

  factory DailySessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemsList = (data['items'] as List? ?? [])
        .map((item) => DailyItemModel.fromMap(item as Map<String, dynamic>))
        .toList();

    return DailySessionModel(
      sessionId: doc.id,
      sessionName: data['sessionName'] ?? '',
      items: itemsList,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionName': sessionName,
      'items': items.map((i) => i.toMap()).toList(),
    };
  }
}
