import 'package:dio/dio.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';

/// Sets `Authorization: Bearer <accessToken>` unless the request is
/// anonymous (register, login, refresh).
final class AuthHeaderInterceptor extends Interceptor {
  new(this._tokens);

  final TokenStorage _tokens;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[RequestExtras.anonymous] != true) {
      final session = await _tokens.read();
      if (session != null) {
        options.headers[HttpHeaderNames.authorization] =
            '${HttpHeaderNames.bearerPrefix}${session.accessToken}';
      }
    }
    handler.next(options);
  }
}

/// The access token a request was sent with, or `null`.
String? bearerTokenOf(RequestOptions options) {
  final header = options.headers[HttpHeaderNames.authorization];
  if (header is String && header.startsWith(HttpHeaderNames.bearerPrefix)) {
    return header.substring(HttpHeaderNames.bearerPrefix.length);
  }
  return null;
}
