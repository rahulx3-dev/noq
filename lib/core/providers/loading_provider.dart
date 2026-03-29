import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A global provider that can be toggled to show the app-level loading splash overlay.
final globalLoadingProvider = StateProvider<bool>((ref) => false);
