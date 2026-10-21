import 'dart:io';

import 'package:dio/dio.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/network/auth_header_interceptor.dart';
import 'package:stockly/core/network/error_mapper.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/network/token_refresher.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';

/// On `401` refreshes the session once and retries the request once
/// (contract §1.4, design §4.3).
///
/// A plain [Interceptor], not a `QueuedInterceptor`: Dio runs the `onError`
/// of a queued interceptor one at a time, so a retry that fails again would
/// wait behind the handler that is awaiting it (deadlock). Concurrent 401s
/// still produce exactly one `POST /api/auth/refresh` because
/// [TokenRefresher.refresh] is single-flight and checks for a stale token.
final class RefreshInterceptor extends Interceptor {
  new({
    required this._dio,
    required this._refresher,
    required this._tokens,
    required this._signals,
  });

  /// The Dio that owns this interceptor; the retry goes through it again.
  final Dio Function() _dio;
  final TokenRefresher _refresher;
  final TokenStorage _tokens;
  final SessionSignals _signals;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    if (err.response?.statusCode != HttpStatus.unauthorized ||
        request.extra[RequestExtras.anonymous] == true) {
      return handler.next(err);
    }
    if (request.extra[RequestExtras.retriedAfterRefresh] == true) {
      final failure = _sessionEndedAfterRetry(err);
      // Only the session this retry was sent with has ended; a sign-in that
      // stored new tokens meanwhile is kept.
      final current = await _tokens.read();
      if (current != null && current.accessToken == bearerTokenOf(request)) {
        await _tokens.clear();
        _signals.sessionEnded(failure);
      }
      return handler.next(_withFailure(err, failure));
    }
    final outcome = await _refresher.refresh(
      staleAccessToken: bearerTokenOf(request) ?? '',
    );
    switch (outcome) {
      case RefreshSucceeded():
        await _retry(err, handler);
      case RefreshSessionEnded(:final failure):
        handler.next(_withFailure(err, failure));
      case RefreshShopSuspended(:final failure):
        handler.next(_withFailure(err, failure));
      case RefreshUnavailable(:final failure):
        handler.next(_withFailure(err, failure));
    }
  }

  Future<void> _retry(DioException err, ErrorInterceptorHandler handler) async {
    final request = err.requestOptions;
    final data = request.data;
    final retry = request.copyWith(
      data: data is FormData ? data.clone() : data,
      extra: {...request.extra, RequestExtras.retriedAfterRefresh: true},
    );
    try {
      handler.resolve(await _dio().fetch<Object?>(retry));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  SessionEndedFailure _sessionEndedAfterRetry(DioException err) {
    final response = err.response;
    final mapped = response == null ? null : mapErrorResponse(response);
    return mapped is SessionEndedFailure
        ? mapped
        : const SessionEndedFailure(
            ApiErrorCode.authUnauthenticated,
            ApiProblemInfo(status: HttpStatus.unauthorized),
          );
  }

  DioException _withFailure(DioException err, Failure failure) =>
      err.copyWith(error: failure);
}
