import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/config/network_timeouts.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/storage/stored_session.dart';

/// Result of one refresh attempt.
@immutable
sealed class RefreshOutcome {
  const new();
}

/// New tokens are stored (by this call or by an earlier one).
final class RefreshSucceeded extends RefreshOutcome {
  const new(this.session);

  final StoredSession session;
}

/// The server rejected the refresh token, or no session is stored. Tokens
/// are cleared.
final class RefreshSessionEnded extends RefreshOutcome {
  const new(this.failure);

  final SessionEndedFailure failure;
}

/// The shop is suspended. Tokens are kept so logout still works (A4).
final class RefreshShopSuspended extends RefreshOutcome {
  const new(this.failure);

  final ShopSuspendedFailure failure;
}

/// The refresh did not reach a decision (offline, timeout, server error).
/// Tokens are kept (checkpoint 2, decision 2).
final class RefreshUnavailable extends RefreshOutcome {
  const new(this.failure);

  final Failure failure;
}

/// Single-flight token refresh (design §4.3): concurrent callers share one
/// `POST /api/auth/refresh`, guarded across isolates by a Drift lease.
final class TokenRefresher {
  new({
    required Dio refreshDio,
    required this._tokens,
    required this._signals,
    required this._leases,
  }) : _dio = refreshDio;

  final Dio _dio;
  final TokenStorage _tokens;
  final SessionSignals _signals;
  final LeaseService _leases;

  Future<RefreshOutcome>? _inFlight;

  /// Refreshes the session whose access token was [staleAccessToken].
  Future<RefreshOutcome> refresh({required String staleAccessToken}) =>
      _inFlight ??= _refreshUnderLease(staleAccessToken)
          .whenComplete(() => _inFlight = null);

  Future<RefreshOutcome> _refreshUnderLease(String staleAccessToken) async {
    final outcome = await _leases.withLease(
      LeaseNames.authRefresh,
      ttl: LeaseTimings.authRefreshTtl,
      wait: NetworkTimeouts.refreshLeaseWait,
      action: () => _refresh(staleAccessToken),
    );
    return outcome ?? const RefreshUnavailable(TimeoutFailure());
  }

  Future<RefreshOutcome> _refresh(String staleAccessToken) async {
    final stored = await _tokens.reload();
    if (stored == null) {
      return await _endSession(_noSessionFailure);
    }
    if (stored.accessToken != staleAccessToken) {
      // Another request or isolate refreshed already: presenting the rotated
      // refresh token again would revoke the whole chain.
      return RefreshSucceeded(stored);
    }
    final result = await safeApiCall(() async {
      final response = await _dio.post<Object?>(
        ApiPaths.authRefresh,
        data: RefreshRequestDto(refreshToken: stored.refreshToken).toJson(),
        options: Options(extra: {RequestExtras.anonymous: true}),
      );
      return AuthResponseDto.fromJson(requireJsonObject(response.data));
    });
    switch (result) {
      case Ok(:final value):
        // Signed out (or in again) while the refresh was out: storing its
        // answer would bring the ended session back on the next start.
        final current = await _tokens.reload();
        if (current == null) {
          return const RefreshSessionEnded(_noSessionFailure);
        }
        if (current.refreshToken != stored.refreshToken) {
          return RefreshSucceeded(current);
        }
        final session = StoredSession.fromAuthResponse(value);
        await _tokens.save(session);
        return RefreshSucceeded(session);
      case Err(:final SessionEndedFailure failure):
        return await _endSession(failure);
      case Err(:final ValidationFailure failure):
        return await _endSession(
          SessionEndedFailure(failure.code, failure.info),
        );
      case Err(:final ShopSuspendedFailure failure):
        _signals.shopSuspended(failure);
        return RefreshShopSuspended(failure);
      case Err(:final failure):
        return RefreshUnavailable(failure);
    }
  }

  Future<RefreshOutcome> _endSession(SessionEndedFailure failure) async {
    await _tokens.clear();
    _signals.sessionEnded(failure);
    return RefreshSessionEnded(failure);
  }

  /// Used when no session is stored: there is nothing to refresh.
  static const SessionEndedFailure _noSessionFailure = SessionEndedFailure(
    ApiErrorCode.authUnauthenticated,
    ApiProblemInfo(status: HttpStatus.unauthorized),
  );
}
