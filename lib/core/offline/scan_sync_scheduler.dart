import 'dart:async';

import 'package:flutter/services.dart';
import 'package:stockly/core/offline/background_sync.dart';
import 'package:stockly/core/platform/connectivity.dart';
import 'package:stockly/core/time/clock.dart';

/// One pass over the upload queue. [force] ignores `nextAttemptAt`. Returns
/// the earliest `nextAttemptAt` still waiting, or `null`.
typedef ScanSyncRun = Future<DateTime?> Function({required bool force});

/// Foreground triggers of the scan upload (design §6.5): start, network
/// back, app resumed, a timer for the earliest waiting row, and explicit
/// requests. Runs never overlap; a request during a run starts one more
/// run after it. The background task is registered here too.
final class ScanSyncScheduler {
  new({
    required this._connectivity,
    required this._background,
    required this._sync,
    required this._clock,
  });

  final ConnectivityMonitor _connectivity;
  final BackgroundSyncRegistrar _background;
  final ScanSyncRun _sync;
  final Clock _clock;

  StreamSubscription<bool>? _subscription;
  Timer? _timer;
  bool? _online;
  bool _started = false;
  bool _disposed = false;
  bool _running = false;

  /// The `force` flag of the run requested while one was running.
  bool? _pendingForce;

  /// Starts listening and runs the queue once. Idempotent.
  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    _subscription = _connectivity.watchOnline().listen(_onConnectivity);
    try {
      await _background.registerPeriodic();
    } on PlatformException {
      // Background work is best-effort (iOS, devices without the service);
      // the foreground triggers still upload.
    } on MissingPluginException {
      // Same: a platform without the background plugin.
    }
    await syncNow();
  }

  /// The app came back to the foreground.
  Future<void> onResumed() => syncNow();

  /// Runs the queue now; [force] ignores `nextAttemptAt` (design §6.4).
  Future<void> syncNow({bool force = false}) async {
    if (_disposed) {
      return;
    }
    if (_running) {
      _pendingForce = (_pendingForce ?? false) || force;
      return;
    }
    _running = true;
    try {
      bool? nextForce = force;
      while (nextForce != null && !_disposed) {
        _schedule(await _sync(force: nextForce));
        nextForce = _pendingForce;
        _pendingForce = null;
      }
    } finally {
      _running = false;
    }
  }

  void _onConnectivity(bool online) {
    final cameBack = online && _online == false;
    _online = online;
    if (cameBack) {
      unawaited(syncNow(force: true));
    }
  }

  void _schedule(DateTime? next) {
    _timer?.cancel();
    _timer = null;
    if (next == null || _disposed) {
      return;
    }
    final delay = next.difference(_clock.now());
    _timer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(syncNow()),
    );
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
  }
}
