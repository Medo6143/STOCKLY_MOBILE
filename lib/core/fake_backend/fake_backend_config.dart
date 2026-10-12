import 'package:flutter/foundation.dart';

/// Knobs of the fake backend (design §12.1).
@immutable
final class FakeBackendConfig {
  const new({
    this.latency = defaultLatency,
    this.accessTokenLifetime = defaultAccessTokenLifetime,
    this.refreshTokenLifetime = defaultRefreshTokenLifetime,
  });

  static const Duration defaultLatency = Duration(milliseconds: 400);

  /// Contract §1.4: 15 minutes. Can be set down to seconds to exercise the
  /// refresh flow.
  static const Duration defaultAccessTokenLifetime = Duration(minutes: 15);

  /// Contract §1.4: 30 days.
  static const Duration defaultRefreshTokenLifetime = Duration(days: 30);

  /// Simulated network delay of every response.
  final Duration latency;
  final Duration accessTokenLifetime;
  final Duration refreshTokenLifetime;
}
