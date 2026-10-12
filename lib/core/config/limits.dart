/// Scan upload limits (design §6).
abstract final class ScanLimits {
  /// Used when a `429 Scan.RateLimited` response has no usable
  /// `Retry-After` header. The server limit is per minute.
  static const Duration defaultRetryAfter = Duration(seconds: 60);
}
