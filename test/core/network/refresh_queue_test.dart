import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/network/token_refresher.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/session/session_signals.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_doubles.dart';
import 'network_harness.dart';

/// A lease that never becomes free.
final class BusyLeaseService implements LeaseService {
  @override
  Future<T?> withLease<T>(
    String name, {
    required Duration ttl,
    required Duration wait,
    required Future<T> Function() action,
  }) async => null;
}

Future<Result<Object?, Failure>> _getProducts(NetworkHarness h) =>
    safeApiCall(() async => (await h.dio.get<Object?>(productsPath)).data);

void main() {
  test('Single401_RefreshesOnceAndRetriesOnce', () async {
    final h = NetworkHarness();

    final result = await _getProducts(h);

    expect(result, isA<Ok<Object?, Failure>>());
    expect(h.refreshCalls, hasLength(1));
    expect(h.adapter.requestsTo(productsPath), hasLength(2));
    expect(h.tokens.session?.accessToken, 'access-2');
    expect(h.tokens.session?.refreshToken, 'refresh-2');
    final refreshBody = h.refreshCalls.single.data as Map<String, dynamic>;
    expect(refreshBody, {'refreshToken': 'refresh-1'});
    expect(
      h.refreshCalls.single.headers[HttpHeaderNames.authorization],
      isNull,
    );
  });

  test('ThreeConcurrent401s_ExactlyOneRefreshAndThreeRetries', () async {
    final h = NetworkHarness();

    final results = await Future.wait([
      _getProducts(h),
      _getProducts(h),
      _getProducts(h),
    ]);

    expect(results, everyElement(isA<Ok<Object?, Failure>>()));
    expect(h.refreshCalls, hasLength(1));
    expect(h.adapter.requestsTo(productsPath), hasLength(6));
    final retries = h.adapter
        .requestsTo(productsPath)
        .where((r) => r.extra[RequestExtras.retriedAfterRefresh] == true);
    expect(retries, hasLength(3));
  });

  test('Late401AfterRefresh_UsesStoredTokenWithoutSecondRefresh', () async {
    final h = NetworkHarness();
    await _getProducts(h);
    // A request that was sent with the old token answers 401 late.
    final stale = await h.refresher.refresh(staleAccessToken: 'access-1');

    expect(stale, isA<RefreshSucceeded>());
    expect(h.refreshCalls, hasLength(1));
  });

  test('RetryAlso401_SessionEndedWithoutSecondRefresh', () async {
    final h = NetworkHarness()
      ..apiAnswer = (_) async => problemBody(401, 'Auth.Unauthenticated');

    final result = await _getProducts(h);

    expect(result, isA<Err<Object?, Failure>>());
    final failure = (result as Err<Object?, Failure>).failure;
    expect(failure, isA<SessionEndedFailure>());
    expect(h.refreshCalls, hasLength(1));
    expect(h.adapter.requestsTo(productsPath), hasLength(2));
    expect(h.tokens.session, isNull);
    expect(h.emitted.whereType<SessionEndedSignal>(), hasLength(1));
  });

  test('RefreshTokenReused_ClearsStorageAndSignalsSessionEnded', () async {
    final h = NetworkHarness()
      ..refreshAnswer = (_) async =>
          problemBody(401, 'Auth.RefreshTokenReused');

    final result = await _getProducts(h);

    final failure = (result as Err<Object?, Failure>).failure;
    expect(failure, isA<SessionEndedFailure>());
    expect(
      (failure as SessionEndedFailure).code,
      ApiErrorCode.authRefreshTokenReused,
    );
    expect(h.tokens.session, isNull);
    expect(h.tokens.clearCount, 1);
    final signal = h.emitted.single as SessionEndedSignal;
    expect(signal.failure.code, ApiErrorCode.authRefreshTokenReused);
    expect(h.adapter.requestsTo(productsPath), hasLength(1));
  });

  test('RefreshInvalidToken_SessionEnded', () async {
    final h = NetworkHarness()
      ..refreshAnswer = (_) async =>
          problemBody(401, 'Auth.InvalidRefreshToken');

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<SessionEndedFailure>());
    expect(h.tokens.session, isNull);
  });

  test('RefreshValidationFailed_SessionEnded', () async {
    final h = NetworkHarness()
      ..refreshAnswer = (_) async => problemBody(400, 'Validation.Failed');

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<SessionEndedFailure>());
    expect(
      (failure as SessionEndedFailure).code,
      ApiErrorCode.validationFailed,
    );
    expect(h.tokens.session, isNull);
  });

  test('RefreshShopSuspended_KeepsTokensAndSignalsSuspension', () async {
    final h = NetworkHarness()
      ..refreshAnswer = (_) async => problemBody(403, 'Shop.Suspended');

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<ShopSuspendedFailure>());
    expect(h.tokens.session?.accessToken, 'access-1');
    expect(h.emitted.single, isA<ShopSuspendedSignal>());
  });

  test('RefreshNetworkError_KeepsTokens', () async {
    final h = NetworkHarness()
      ..refreshAnswer = (options) async => throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<NetworkFailure>());
    expect(h.tokens.session?.accessToken, 'access-1');
    expect(h.tokens.clearCount, 0);
    expect(h.emitted, isEmpty);
  });

  test('RefreshServerError_KeepsTokens', () async {
    final h = NetworkHarness()
      ..refreshAnswer = (_) async => problemBody(500, 'Server.Unexpected');

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<ServerFailure>());
    expect(h.tokens.session?.accessToken, 'access-1');
  });

  test('RefreshMalformedBody_KeepsTokens', () async {
    final h = NetworkHarness()
      ..refreshAnswer = (_) async => jsonBody(200, {'unexpected': true});

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<MalformedResponseFailure>());
    expect(h.tokens.session?.accessToken, 'access-1');
  });

  test('StaleToken_AnotherIsolateRefreshed_NoRefreshCall', () async {
    final h = NetworkHarness();
    h.tokens.reloadSession = storedSession(
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
    );

    final result = await _getProducts(h);

    expect(result, isA<Ok<Object?, Failure>>());
    expect(h.refreshCalls, isEmpty);
    final retry = h.adapter.requestsTo(productsPath).last;
    expect(
      retry.headers[HttpHeaderNames.authorization],
      '${HttpHeaderNames.bearerPrefix}access-2',
    );
  });

  test('NoStoredSession_SessionEndedWithoutRefreshCall', () async {
    final h = NetworkHarness();
    h.tokens.session = null;

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<SessionEndedFailure>());
    expect(h.refreshCalls, isEmpty);
    expect(h.emitted.single, isA<SessionEndedSignal>());
  });

  test(
    'AnotherShopSignedInBeforeTheRetry_RetryNotSentAndItsSessionKept',
    () async {
      // Signed out of this shop and into another while the request was out:
      // the retry must not carry the other shop's token.
      final h = NetworkHarness();
      h.tokens.reloadSession = storedSession(
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
        shopId: otherShopId,
      );

      final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

      expect(failure, isA<SessionEndedFailure>());
      expect(h.adapter.requestsTo(productsPath), hasLength(1));
      expect(h.refreshCalls, isEmpty);
      expect(h.tokens.session?.shop.id, otherShopId);
      expect(h.tokens.clearCount, 0);
      expect(h.emitted.whereType<SessionEndedSignal>(), isEmpty);
    },
  );

  test('RequestForAnotherShop_NotSent', () async {
    final h = NetworkHarness();

    final result = await safeApiCall(
      () async => (await h.dio.get<Object?>(
        productsPath,
        options: Options(extra: {RequestExtras.shopId: otherShopId}),
      )).data,
    );

    expect(
      (result as Err<Object?, Failure>).failure,
      isA<SessionEndedFailure>(),
    );
    expect(h.adapter.requestsTo(productsPath), isEmpty);
    expect(h.tokens.clearCount, 0);
  });

  test('RetryAlso401AfterANewSignIn_NewSessionKept', () async {
    // The retry was sent with access-2, and a new sign-in stored access-9
    // before its 401 came back: that 401 does not end the new session.
    final h = NetworkHarness();
    h.apiAnswer = (options) async {
      if (options.extra[RequestExtras.retriedAfterRefresh] == true) {
        h.tokens.session = storedSession(accessToken: 'access-9');
      }
      return problemBody(401, 'Auth.Unauthenticated');
    };

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<SessionEndedFailure>());
    expect(h.tokens.session?.accessToken, 'access-9');
    expect(h.tokens.clearCount, 0);
    expect(h.emitted.whereType<SessionEndedSignal>(), isEmpty);
  });

  test('SignedOutWhileRefreshing_NewTokensNotStored', () async {
    // Logout cleared the tokens while the refresh was out: storing its
    // answer would sign the user back in on the next start.
    final h = NetworkHarness();
    h.refreshAnswer = (_) async {
      h.tokens.session = null;
      return jsonBody(
        200,
        authResponseJson(accessToken: 'access-2', refreshToken: 'refresh-2'),
      );
    };

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<SessionEndedFailure>());
    expect(h.tokens.session, isNull);
    expect(h.tokens.saveCount, 0);
    expect(h.emitted.whereType<SessionEndedSignal>(), isEmpty);
  });

  test('RefreshTimeouts_EndBeforeItsLeaseExpires', () {
    // A refresh that outlives its lease lets another isolate present the
    // same refresh token, and the server then revokes the whole chain.
    final options = buildRefreshDio(
      config: const AppConfig(apiBaseUrl: 'https://api.stockly.test'),
      uuid: CountingUuidGenerator(),
      languageCode: () => 'ar',
      logger: RecordingLogger(),
      logRequests: false,
    ).options;

    final longest =
        options.connectTimeout! +
        options.sendTimeout! +
        options.receiveTimeout!;
    expect(longest, lessThan(LeaseTimings.authRefreshTtl));
  });

  test('LeaseBusy_RefreshUnavailable_TokensKept', () async {
    final h = NetworkHarness(leases: BusyLeaseService());

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<TimeoutFailure>());
    expect(h.refreshCalls, isEmpty);
    expect(h.tokens.session?.accessToken, 'access-1');
  });

  test('MultipartRetry_UsesClonedFormData', () async {
    final h = NetworkHarness();
    final form = FormData.fromMap({
      'clientRequestId': '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d99',
      'image': MultipartFile.fromBytes([1, 2, 3], filename: 'scan.jpg'),
    });

    final result = await safeApiCall(
      () => h.dio.post<Object?>(productsPath, data: form),
    );

    expect(result, isA<Ok<Object?, Failure>>());
    final attempts = h.adapter.requestsTo(productsPath);
    expect(attempts, hasLength(2));
    final retried = attempts.last.data;
    expect(retried, isA<FormData>());
    expect(retried, isNot(same(form)));
    final field = (retried as FormData).fields.single;
    expect(field.key, 'clientRequestId');
    expect(field.value, '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d99');
    expect(retried.files.single.value.filename, 'scan.jpg');
  });

  test('Anonymous401_IsNotRefreshed', () async {
    final h = NetworkHarness()
      ..apiAnswer = (_) async => problemBody(401, 'Auth.InvalidCredentials');

    final result = await safeApiCall(
      () => h.dio.post<Object?>(
        ApiPaths.authLogin,
        options: Options(extra: {RequestExtras.anonymous: true}),
      ),
    );

    expect(
      (result as Err<Object?, Failure>).failure,
      isA<InvalidCredentialsFailure>(),
    );
    expect(h.refreshCalls, isEmpty);
  });

  test('Non401Error_PassesThroughWithoutRefresh', () async {
    final h = NetworkHarness()
      ..apiAnswer = (_) async => problemBody(404, 'Product.NotFound');

    final failure = (await _getProducts(h) as Err<Object?, Failure>).failure;

    expect(failure, isA<NotFoundFailure>());
    expect(h.refreshCalls, isEmpty);
  });
}
