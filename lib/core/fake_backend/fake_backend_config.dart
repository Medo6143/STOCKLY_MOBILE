import 'package:flutter/foundation.dart';

/// Knobs of the fake backend (design §12.1). Values default to the
/// contract's; the switches start from [lockoutEnabled] and
/// [rateLimitEnabled] and can be flipped at runtime through
/// `FakeBackendControls` (debug panel).
@immutable
final class FakeBackendConfig {
  const new({
    this.latency = defaultLatency,
    this.accessTokenLifetime = defaultAccessTokenLifetime,
    this.refreshTokenLifetime = defaultRefreshTokenLifetime,
    this.lockoutEnabled = true,
    this.lockoutThreshold = defaultLockoutThreshold,
    this.lockoutDuration = defaultLockoutDuration,
    this.rateLimitEnabled = true,
    this.authPermitLimit = defaultAuthPermitLimit,
    this.authWindow = defaultAuthWindow,
    this.processingDelay = defaultProcessingDelay,
    this.scanRateLimit = defaultScanRateLimit,
    this.scanRateWindow = defaultScanRateWindow,
    this.scanDailyQuota = defaultScanDailyQuota,
  });

  static const Duration defaultLatency = Duration(milliseconds: 400);

  /// Contract §1.4: 15 minutes. Can be set down to seconds to exercise the
  /// refresh flow.
  static const Duration defaultAccessTokenLifetime = Duration(minutes: 15);

  /// Contract §1.4: 30 days.
  static const Duration defaultRefreshTokenLifetime = Duration(days: 30);

  /// Contract §1.4 (v1.4): 5 failed logins in a row lock the account.
  static const int defaultLockoutThreshold = 5;

  /// Contract §1.4 (v1.4): for 15 minutes.
  static const Duration defaultLockoutDuration = Duration(minutes: 15);

  /// Contract §1.4 (v1.4): 10 login or register requests per window.
  static const int defaultAuthPermitLimit = 10;

  /// Contract §1.4 (v1.4): fixed one-minute window.
  static const Duration defaultAuthWindow = Duration(minutes: 1);

  /// Design §12.1: a scan turns `NeedsReview` (or `Failed`) after 6 s.
  static const Duration defaultProcessingDelay = Duration(seconds: 6);

  /// Scans accepted per [scanRateWindow] and shop (`Scan.RateLimited`).
  static const int defaultScanRateLimit = 10;
  static const Duration defaultScanRateWindow = Duration(minutes: 1);

  /// Scans per Cairo day and shop (`Scan.DailyQuotaExceeded`).
  static const int defaultScanDailyQuota = 50;

  /// Simulated network delay of every response.
  final Duration latency;
  final Duration accessTokenLifetime;
  final Duration refreshTokenLifetime;

  /// Initial state of the account lockout switch.
  final bool lockoutEnabled;
  final int lockoutThreshold;
  final Duration lockoutDuration;

  /// Initial state of the login/register rate-limit switch.
  final bool rateLimitEnabled;

  /// Requests allowed per [authWindow], per endpoint.
  final int authPermitLimit;
  final Duration authWindow;

  /// How long the fake AI takes to read a scan, on the fake clock.
  final Duration processingDelay;
  final int scanRateLimit;
  final Duration scanRateWindow;
  final int scanDailyQuota;
}
