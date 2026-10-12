import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/auth_header_interceptor.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/session/session_signals.dart';

import '../../helpers/scripted_adapter.dart';
import 'network_harness.dart';

final RegExp _correlationIdFormat = RegExp(r'^[A-Za-z0-9._-]{1,64}$');
final RegExp _lowerUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  test('AcceptLanguage_FollowsLocaleWithoutRebuildingDio', () async {
    final h = NetworkHarness()..validAccessToken = 'access-1';
    final dio = h.dio;

    await h.dio.get<Object?>(productsPath);
    h.language = 'en';
    await h.dio.get<Object?>(productsPath);

    expect(identical(dio, h.dio), isTrue);
    final sent = h.adapter
        .requestsTo(productsPath)
        .map((r) => r.headers[HttpHeaderNames.acceptLanguage]);
    expect(sent, ['ar', 'en']);
  });

  test('CorrelationId_NewLowerCaseUuidPerRequest', () async {
    final h = NetworkHarness()..validAccessToken = 'access-1';

    await h.dio.get<Object?>(productsPath);
    await h.dio.get<Object?>(productsPath);

    final ids = h.adapter
        .requestsTo(productsPath)
        .map((r) => r.headers[HttpHeaderNames.correlationId] as String)
        .toList();
    expect(ids, everyElement(matches(_lowerUuid)));
    expect(ids, everyElement(matches(_correlationIdFormat)));
    expect(ids.toSet(), hasLength(2));
  });

  test('CorrelationId_ReusedOnRetryAfterRefresh', () async {
    final h = NetworkHarness();

    await h.dio.get<Object?>(productsPath);

    final attempts = h.adapter.requestsTo(productsPath);
    expect(attempts, hasLength(2));
    expect(
      attempts.first.headers[HttpHeaderNames.correlationId],
      attempts.last.headers[HttpHeaderNames.correlationId],
    );
  });

  test('AnonymousRequest_HasNoAuthorization', () async {
    final h = NetworkHarness()
      ..apiAnswer = (_) async => jsonBody(200, {'ok': true});

    await h.dio.post<Object?>(
      ApiPaths.authLogin,
      options: Options(extra: {RequestExtras.anonymous: true}),
    );
    await h.dio.get<Object?>(productsPath);

    final login = h.adapter.requestsTo(ApiPaths.authLogin).single;
    expect(login.headers[HttpHeaderNames.authorization], isNull);
    final products = h.adapter.requestsTo(productsPath).single;
    expect(
      products.headers[HttpHeaderNames.authorization],
      '${HttpHeaderNames.bearerPrefix}access-1',
    );
    expect(bearerTokenOf(products), 'access-1');
    expect(bearerTokenOf(login), isNull);
  });

  test('NoSession_RequestSentWithoutAuthorization', () async {
    final h = NetworkHarness()
      ..apiAnswer = (_) async => jsonBody(200, {'ok': true});
    h.tokens.session = null;

    await h.dio.get<Object?>(productsPath);

    expect(
      h.adapter
          .requestsTo(productsPath)
          .single
          .headers[HttpHeaderNames.authorization],
      isNull,
    );
  });

  test('ShopSuspended_EmitsSignalAndMapsFailure', () async {
    final h = NetworkHarness()
      ..apiAnswer = (_) async => problemBody(403, 'Shop.Suspended');

    final result = await safeApiCall(() => h.dio.get<Object?>(productsPath));
    await pumpEventQueue();

    expect(
      (result as Err<Object?, Failure>).failure,
      isA<ShopSuspendedFailure>(),
    );
    expect(h.emitted.single, isA<ShopSuspendedSignal>());
  });

  test('OtherForbidden_NoSuspensionSignal', () async {
    final h = NetworkHarness()
      ..apiAnswer = (_) async => problemBody(403, 'Auth.Forbidden');

    await safeApiCall(() => h.dio.get<Object?>(productsPath));
    await pumpEventQueue();

    expect(h.emitted, isEmpty);
  });

  test('Log_NeverContainsTokensPasswordsOrSearchValues', () async {
    final h = NetworkHarness();
    h.adapter.respond = (options) async => options.path == ApiPaths.authLogin
        ? jsonBody(
            200,
            authResponseJson(
              accessToken: 'secret-access',
              refreshToken: 'secret-refresh',
            ),
          )
        : problemBody(404, 'Product.NotFound');

    await safeApiCall(
      () => h.dio.post<Object?>(
        ApiPaths.authLogin,
        data: {'email': 'mona@stockly.test', 'password': 'P4ssword!'},
        options: Options(extra: {RequestExtras.anonymous: true}),
      ),
    );
    await safeApiCall(
      () => h.dio.get<Object?>(
        productsPath,
        queryParameters: {'search': 'بنادول', 'page': '2'},
      ),
    );

    final log = h.logger.lines.join('\n');
    expect(h.logger.lines, hasLength(2));
    for (final secret in [
      'access-1',
      'secret-access',
      'secret-refresh',
      'refresh-1',
      'P4ssword!',
      'mona@stockly.test',
      'بنادول',
      'Bearer',
    ]) {
      expect(log, isNot(contains(secret)), reason: secret);
    }
    expect(log, contains('POST ${ApiPaths.authLogin} -> 200'));
    expect(log, contains('page=2'));
    expect(log, contains('code=Product.NotFound'));
    expect(log, contains('traceId=00-trace-00'));
  });
}
