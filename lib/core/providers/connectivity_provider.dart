import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ConnectivityStatus { online, offline }

/// A stream provider that monitors the device's internet connectivity status.
final connectivityStreamProvider = StreamProvider<ConnectivityStatus>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    // connectivity_plus 6.0+ returns a List<ConnectivityResult>
    // If it's empty or contains only 'none', we are offline.
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return ConnectivityStatus.offline;
    }
    return ConnectivityStatus.online;
  });
});

/// A simpler provider to watch the current (optional) status.
final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.when(
    data: (status) => status == ConnectivityStatus.offline,
    loading: () => false, // Assume online until checked
    error: (_, __) => false,
  );
});
