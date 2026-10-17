import 'dart:math';

import 'package:stockly/core/config/limits.dart';

/// Wait before the next upload attempt after a transient failure (design
/// §6.4): `min(base × 2^(attempt − 1), max)` with ±[jitter] from [_random].
/// There is no attempt limit: retries are free (ADR-0006).
final class BackoffPolicy {
  new(
    this._random, {
    this.base = SyncTimings.backoffBase,
    this.max = SyncTimings.backoffMax,
    this.jitter = SyncTimings.backoffJitter,
  });

  final Random _random;
  final Duration base;
  final Duration max;
  final double jitter;

  /// The delay after attempt number [attempt] (1-based) failed.
  Duration delayFor(int attempt) {
    final exponent = attempt < 1 ? 0 : attempt - 1;
    final maxMs = max.inMilliseconds;
    var ms = base.inMilliseconds;
    for (var i = 0; i < exponent && ms < maxMs; i++) {
      ms *= 2;
    }
    final capped = ms < maxMs ? ms : maxMs;
    final factor = 1 + jitter * (2 * _random.nextDouble() - 1);
    return Duration(milliseconds: (capped * factor).round());
  }
}
