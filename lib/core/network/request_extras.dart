/// Keys of `RequestOptions.extra` used by the interceptors (design §4.1).
abstract final class RequestExtras {
  /// `true` for register, login and refresh: no `Authorization` header and
  /// no refresh on `401`.
  static const String anonymous = 'stockly.anonymous';

  /// `true` on the one retry after a refresh.
  static const String retriedAfterRefresh = 'stockly.retriedAfterRefresh';

  /// The `X-Correlation-Id` of the logical request, reused by the retry.
  static const String correlationId = 'stockly.correlationId';

  /// The shop a request belongs to: set by the caller (a queued row) or
  /// stamped on the first send, kept by the retry. A request is never sent
  /// with the token of another shop.
  static const String shopId = 'stockly.shopId';
}

/// HTTP header names and values the app sets or reads.
abstract final class HttpHeaderNames {
  static const String authorization = 'Authorization';
  static const String acceptLanguage = 'Accept-Language';
  static const String correlationId = 'X-Correlation-Id';
  static const String retryAfter = 'Retry-After';
  static const String contentType = 'Content-Type';
  static const String bearerPrefix = 'Bearer ';
}
