import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:qcutapp/core/firebase_options.dart';

/// Initializes Firebase for the app.
///
/// Must be called before runApp() in main.dart.
Future<void> initializeFirebase() async {
  debugPrint('DEBUG: Initializing Firebase...');
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('DEBUG: Firebase initialized successfully');
    } else {
      debugPrint('DEBUG: Firebase already initialized, skipping');
    }
  } catch (e) {
    debugPrint('DEBUG: Firebase initialization error: $e');
  }
}
