import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has a network (design §14, `connectivity_plus`). A
/// network does not guarantee the API is reachable; uploads still decide
/// by their own result.
abstract interface class ConnectivityMonitor {
  /// The current state first, then every change.
  Stream<bool> watchOnline();
}

final class PluginConnectivityMonitor implements ConnectivityMonitor {
  const new(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<bool> watchOnline() async* {
    yield _isOnline(await _connectivity.checkConnectivity());
    yield* _connectivity.onConnectivityChanged.map(_isOnline).distinct();
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}

final connectivityMonitorProvider = Provider<ConnectivityMonitor>(
  (ref) => PluginConnectivityMonitor(Connectivity()),
);

/// `true` while the device has a network (design §2.2).
final connectivityProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityMonitorProvider).watchOnline(),
);
