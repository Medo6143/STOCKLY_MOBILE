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

  /// `POST /api/auth/refresh` is a small JSON call. Its [connect] +
  /// [refreshSend] + [refreshReceive] stay below
  /// `LeaseTimings.authRefreshTtl`: a refresh that outlives its lease lets
  /// another isolate present the same refresh token, and the server then
  /// revokes the whole chain.
  static const Duration refreshSend = Duration(seconds: 5);
  static const Duration refreshReceive = Duration(seconds: 10);
}
