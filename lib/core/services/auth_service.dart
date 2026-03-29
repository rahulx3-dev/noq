import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Wraps [FirebaseAuth] to provide a clean API for authentication operations.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth, FirebaseFirestore? firestore})
    : _auth = firebaseAuth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Stream of auth state changes (logged-in / logged-out).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently signed-in user, or `null`.
  User? get currentUser => _auth.currentUser;

  /// Sign up with email and password (Student only)
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
    required String studentId,
  }) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;
      if (user != null) {
        // Create student profile in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'role': 'student', // Enforce student role
          'studentId': studentId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send email verification
        await user.sendEmailVerification();
      }
      return user;
    } catch (e) {
      rethrow;
    }
  }

  /// Signs in an existing user with [email] and [password].
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sends a password-reset email to [email].
  Future<void> resetPassword({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Updates the user's display name in Firebase Auth and their Firestore profile.
  Future<void> updateProfile({required String displayName}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Update Firebase Auth
    await user.updateDisplayName(displayName);

    // Update Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'name': displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
