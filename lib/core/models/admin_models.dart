import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String name;
  final String startTime;
  final String endTime;
  final int defaultInterval; // in minutes
  final int defaultCapacity;
  final bool isActive;
  final int order;
  final List<Map<String, dynamic>> customSlots;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SessionModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.defaultInterval = 30,
    this.defaultCapacity = 20,
    required this.isActive,
    required this.order,
    this.customSlots = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SessionModel(
      id: doc.id,
      name: data['name'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      defaultInterval: data['defaultInterval'] ?? 30,
      defaultCapacity: data['defaultCapacity'] ?? 20,
      isActive: data['isActive'] ?? true,
      order: data['order'] ?? 0,
      customSlots:
          (data['customSlots'] as List?)
              ?.map((s) => s as Map<String, dynamic>)
              .toList() ??
          const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'defaultInterval': defaultInterval,
      'defaultCapacity': defaultCapacity,
      'isActive': isActive,
      'order': order,
      'customSlots': customSlots,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SessionModel copyWith({
    String? id,
    String? name,
    String? startTime,
    String? endTime,
    int? defaultInterval,
    int? defaultCapacity,
    bool? isActive,
    int? order,
    List<Map<String, dynamic>>? customSlots,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      defaultInterval: defaultInterval ?? this.defaultInterval,
      defaultCapacity: defaultCapacity ?? this.defaultCapacity,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      customSlots: customSlots ?? this.customSlots,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CategoryModel {
  final String id;
  final String name;
  final bool isActive;
  final bool isPreReady;
  final int order;
  final DateTime? createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.isActive,
    this.isPreReady = false,
    required this.order,
    this.createdAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      isActive: data['isActive'] ?? true,
      isPreReady: data['isPreReady'] ?? data['isReadyMade'] ?? false,
      order: data['order'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
      'isPreReady': isPreReady,
      'order': order,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    bool? isActive,
    bool? isPreReady,
    int? order,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      isPreReady: isPreReady ?? this.isPreReady,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class MenuItemModel {
  final String id;
  final String name;
  final String description; // added
  final double price;
  final String categoryId;
  final String category; // Added for easy filtering
  final List<String> categoryIds; // Added for multiple categories
  final List<String> categoryNames; // Added for multiple categories
  final String? imageUrl;
  final bool isAvailable;
  final bool isPreReady; // Added
  final bool isGlobal; // Added
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MenuItemModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.categoryId,
    this.category = '', // Added
    this.categoryIds = const [], // Added
    this.categoryNames = const [], // Added
    this.imageUrl,
    required this.isAvailable,
    this.isPreReady = false, // Added
    this.isGlobal = false, // Added
    this.createdAt,
    this.updatedAt,
  });

  factory MenuItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuItemModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      categoryId: data['categoryId'] ?? '',
      category: data['category'] ?? '', // Added
      categoryIds: (data['categoryIds'] as List?)?.map((e) => e.toString()).toList() ?? [], // Added
      categoryNames: (data['categoryNames'] as List?)?.map((e) => e.toString()).toList() ?? [], // Added
      imageUrl: data['imageUrl'],
      isAvailable: data['isAvailable'] ?? true,
      isPreReady: data['isPreReady'] ?? data['isReadyMade'] ?? false, // Added
      isGlobal: data['isGlobal'] ?? false, // Added
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'category': category, // Added
      'categoryIds': categoryIds, // Added
      'categoryNames': categoryNames, // Added
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'isPreReady': isPreReady, // Added
      'isGlobal': isGlobal, // Added
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  MenuItemModel copyWith({
    String? id,
    String? name,
    String? description, // added
    double? price,
    String? categoryId,
    String? category, // Added
    List<String>? categoryIds, // Added
    List<String>? categoryNames, // Added
    String? imageUrl,
    bool? isAvailable,
    bool? isPreReady, // Added
    bool? isGlobal, // Added
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category, // Added
      categoryIds: categoryIds ?? this.categoryIds, // Added
      categoryNames: categoryNames ?? this.categoryNames, // Added
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isPreReady: isPreReady ?? this.isPreReady, // Added
      isGlobal: isGlobal ?? this.isGlobal, // Added
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class SlotModel {
  final String id;
  final String startTime;
  final String endTime;
  final int capacity;
  final int remainingCapacity;

  SlotModel({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.remainingCapacity,
  });

  factory SlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SlotModel(
      id: doc.id,
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      capacity: data['capacity'] ?? 0,
      remainingCapacity: data['remainingCapacity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startTime': startTime,
      'endTime': endTime,
      'capacity': capacity,
      'remainingCapacity': remainingCapacity,
    };
  }
}

class DailyMenuModel {
  final String date;
  final String releaseMode;
  final DateTime? createdAt;

  DailyMenuModel({
    required this.date,
    required this.releaseMode,
    this.createdAt,
  });

  factory DailyMenuModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyMenuModel(
      date: doc.id,
      releaseMode: data['releaseMode'] ?? 'session',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'releaseMode': releaseMode,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
