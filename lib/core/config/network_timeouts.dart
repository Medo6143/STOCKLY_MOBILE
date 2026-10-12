/// Network timeouts (design §4.1). Named constants, never inline durations.
abstract final class NetworkTimeouts {
  static const Duration connect = Duration(seconds: 10);

  /// Long enough for a scan upload on a weak network.
  static const Duration send = Duration(seconds: 60);
  static const Duration receive = Duration(seconds: 30);

  /// Only `GET /api/auth/me` during the splash, so the splash maximum of
  /// 3 s holds (design §10.2).
  static const Duration meStartup = Duration(milliseconds: 2500);

  /// How long a refresh waits for the cross-isolate `authRefresh` lease.
  static const Duration refreshLeaseWait = Duration(seconds: 10);
}
