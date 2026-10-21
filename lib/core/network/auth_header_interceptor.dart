import 'dart:io';

import 'package:dio/dio.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';

/// Sets `Authorization: Bearer <accessToken>` unless the request is
/// anonymous (register, login, refresh).
///
/// A request belongs to one shop ([RequestExtras.shopId]): the caller may
/// name it, otherwise the first send stamps the current one and the retry
/// keeps it. When the stored session is of another shop (signed out and
/// into another shop while the request was queued or out), the request is
/// not sent: it would land in the wrong shop.
final class AuthHeaderInterceptor extends Interceptor {
  new(this._tokens);

  final TokenStorage _tokens;

  /// The session the request was made for has ended.
  static const SessionEndedFailure _otherShopFailure = SessionEndedFailure(
    ApiErrorCode.authUnauthenticated,
    ApiProblemInfo(status: HttpStatus.unauthorized),
  );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[RequestExtras.anonymous] == true) {
      return handler.next(options);
    }
    final session = await _tokens.read();
    final shopId = options.extra[RequestExtras.shopId];
    if (shopId != null && session?.shop.id != shopId) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: _otherShopFailure,
        ),
      );
    }
    if (session != null) {
      options
        ..extra[RequestExtras.shopId] = session.shop.id
        ..headers[HttpHeaderNames.authorization] =
            '${HttpHeaderNames.bearerPrefix}${session.accessToken}';
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
