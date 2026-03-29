import 'package:cloud_firestore/cloud_firestore.dart';

enum MenuCategory { breakfast, lunch, snacks, dinner, beverages, other }

class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final MenuCategory category;
  final bool isAvailable;
  final bool isPreReady;
  final DateTime updatedAt;

  MenuItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    required this.isAvailable,
    this.isPreReady = false,
    required this.updatedAt,
  });

  factory MenuItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuItemModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'],
      category: _parseCategory(data['category']),
      isAvailable: data['isAvailable'] ?? true,
      isPreReady: data['isPreReady'] ?? false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category.name,
      'isAvailable': isAvailable,
      'isPreReady': isPreReady,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static MenuCategory _parseCategory(String? category) {
    return MenuCategory.values.firstWhere(
      (e) => e.name == category,
      orElse: () => MenuCategory.other,
    );
  }
}
