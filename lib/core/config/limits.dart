/// Scan capture and upload limits (design §6.1, contract I1).
abstract final class ScanLimits {
  /// Used when a `429 Scan.RateLimited` response has no usable
  /// `Retry-After` header. The server limit is per minute.
  static const Duration defaultRetryAfter = Duration(seconds: 60);

  /// Long edge of the uploaded photo in pixels.
  static const int maxLongEdgePx = 2000;

  /// JPEG quality of the uploaded photo.
  static const int jpegQuality = 80;

  /// Contract I1: the server rejects images over 8 MB.
  static const int maxUploadBytes = 8 * 1024 * 1024;

  /// Rows the queue keeps per shop (checkpoint 2, decision 12).
  static const int maxPendingScans = 50;

  /// Every queued photo is a JPEG after compression.
  static const String jpegMimeType = 'image/jpeg';

  /// File extension of a queued photo.
  static const String jpegExtension = '.jpg';

  /// Folder under the app support directory holding queued photos.
  static const String pendingScansFolder = 'pending_scans';
}

/// Timings of the scan upload queue (design §6.4, §6.5).
abstract final class SyncTimings {
  /// A sync run holds the `scanSync` lease at most this long per row, and a
  /// row stuck in `uploading` longer than this goes back to `queued`.
  static const Duration leaseTtl = Duration(minutes: 2);

  /// How long an upload waits for the `scanSync` lease.
  static const Duration leaseWait = Duration(seconds: 5);

  /// Recheck after `429 Scan.DailyQuotaExceeded` without `Retry-After`.
  static const Duration quotaRecheck = Duration(hours: 1);

  /// Backoff after a transient failure: base × 2^(attempt − 1), capped.
  static const Duration backoffBase = Duration(seconds: 30);
  static const Duration backoffMax = Duration(minutes: 30);

  /// ±20% jitter on the backoff.
  static const double backoffJitter = 0.2;

  /// The capture screen waits this long for the first upload.
  static const Duration captureWait = Duration(seconds: 10);

  /// Android's minimum period for the background task.
  static const Duration periodic = Duration(minutes: 15);
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
