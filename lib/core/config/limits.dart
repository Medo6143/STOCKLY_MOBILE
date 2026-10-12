/// Scan upload limits (design §6).
abstract final class ScanLimits {
  /// Used when a `429 Scan.RateLimited` response has no usable
  /// `Retry-After` header. The server limit is per minute.
  static const Duration defaultRetryAfter = Duration(seconds: 60);
}

/// Login and register limits (contract v1.4 §1.4).
abstract final class AuthLimits {
  /// Used when a `423 Auth.LockedOut` response has no usable `Retry-After`:
  /// the server locks an account for 15 minutes.
  static const Duration defaultLockout = Duration(minutes: 15);

  /// Used when a `429 Auth.TooManyRequests` response has no usable
  /// `Retry-After`: the server window is one minute.
  static const Duration defaultRetryAfter = Duration(seconds: 60);
}
