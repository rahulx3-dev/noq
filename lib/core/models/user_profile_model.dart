import 'package:cloud_firestore/cloud_firestore.dart';

/// The three roles a user can have in the app.
enum UserRole {
  student,
  staff,
  admin;

  /// Parse a Firestore string value into a [UserRole].
  static UserRole fromString(String value) {
    final normalized = value.trim().toLowerCase();
    
    // Map administrative roles to admin
    if (normalized == 'admin') return UserRole.admin;
    
    // Map all staff variations to staff
    if (normalized == 'staff' || 
        normalized == 'kitchen_staff' || 
        normalized == 'kitchen staff' ||
        normalized == 'counter_staff' ||
        normalized == 'counter staff' ||
        normalized == 'manager' ||
        normalized == 'chef') {
      return UserRole.staff;
    }
    
    // Default to student
    return UserRole.student;
  }
}

/// Represents a user's profile stored in Firestore `/users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
    this.staffRole,
    this.studentId = '',
    this.department = '',
    this.year = '',
    this.orderAlertsEnabled = false,
    this.imageUrl,
    this.phone = '',
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? staffRole;
  final DateTime createdAt;
  final String studentId;
  final String department;
  final String year;
  final bool orderAlertsEnabled;
  final String? imageUrl;
  final String phone;

  /// Creates a [UserProfile] from a Firestore document snapshot.
  factory UserProfile.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final roleStr = (data['role'] as String? ?? 'student').toLowerCase();
    
    return UserProfile(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: UserRole.fromString(roleStr),
      staffRole: data['staffRole'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      studentId: data['studentId'] as String? ?? '',
      department: data['department'] as String? ?? '',
      year: data['year'] as String? ?? '',
      orderAlertsEnabled: data['orderAlertsEnabled'] as bool? ?? false,
      imageUrl: data['imageUrl'] as String?,
      phone: data['phone'] as String? ?? '',
    );
  }

  /// Converts this profile to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.name, // Saves 'staff' if role is UserRole.staff
      'staffRole': staffRole,
      'createdAt': Timestamp.fromDate(createdAt),
      'studentId': studentId,
      'department': department,
      'year': year,
      'orderAlertsEnabled': orderAlertsEnabled,
      'imageUrl': imageUrl,
      'phone': phone,
    };
  }
}
