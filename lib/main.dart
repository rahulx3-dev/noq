import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qcutapp/app/app.dart';
import 'package:qcutapp/core/firebase_init.dart';

void main() async {
  debugPrint('DEBUG: Calling WidgetsFlutterBinding.ensureInitialized()');
  WidgetsFlutterBinding.ensureInitialized();

  await initializeFirebase();

  debugPrint('DEBUG: Calling runApp(QCutApp)');
  runApp(const ProviderScope(child: QCutApp()));
}
