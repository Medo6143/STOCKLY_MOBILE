import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/request_extras.dart';

import '../helpers/fake_app.dart';
import '../helpers/test_doubles.dart';
import 'json_shape.dart';

/// Contract A1–A5 (v1.3 §4) against the fake backend: status codes, error
/// codes and JSON shapes from the contract fixtures.
void main() {
  late FakeClock clock;
  late FakeBackendState state;
  late FakeBackendAdapter adapter;
  late Dio dio;

  setUp(() {
    clock = FakeClock();
    state = FakeSeed.pharmacy(clock.now());
    adapter = fakeBackend(clock: clock, state: state);
    dio = rawDio(adapter)
      ..options.validateStatus = ((_) => true)
      ..options.headers[HttpHeaderNames.acceptLanguage] = 'en';
  });

  Future<Response<Object?>> post(
    String path,
    Object? body, {
    String? token,
    String language = 'en',
  }) => dio.post<Object?>(
    path,
    data: body,
    options: Options(
      headers: {
        HttpHeaderNames.acceptLanguage: language,
        if (token != null)
          HttpHeaderNames.authorization:
              '${HttpHeaderNames.bearerPrefix}$token',
      },
    ),
  );

  Future<Response<Object?>> me(String? token) => dio.get<Object?>(
    ApiPaths.authMe,
    options: Options(
      headers: {
        if (token != null)
          HttpHeaderNames.authorization:
              '${HttpHeaderNames.bearerPrefix}$token',
      },
    ),
  );

  Map<String, Object?> json(Response<Object?> response) =>
      response.data! as Map<String, Object?>;

  void expectProblem(
    Response<Object?> response,
    int status,
    String code, {
    bool withErrors = false,
  }) {
    expect(response.statusCode, status, reason: '${response.data}');
    expect(
      response.headers.value(Headers.contentTypeHeader),
      startsWith('application/problem+json'),
    );
    final body = json(response);
    expect(body['code'], code);
    expect(body['status'], status);
    final expectedKeys = fixture('problem_details').keys.toSet();
    expect(
      body.keys.toSet(),
      withErrors ? {...expectedKeys, 'errors'} : expectedKeys,
    );
    expect(body['correlationId'], response.headers.value('x-correlation-id'));
  }

  Future<Map<String, Object?>> login({
    String email = FakeSeed.ownerEmail,
  }) async {
    final response = await post(ApiPaths.authLogin, {
      'email': email,
      'password': FakeSeed.password,
      'deviceId': 'device-1',
    });
    expect(response.statusCode, HttpStatus.ok);
    return json(response);
  }

  Map<String, Object?> registerBody({
    String email = 'new@stockly.test',
    String password = 'Str0ngPass',
    Object? shop,
  }) => {
    'fullName': 'Mona Adel',
    'email': email,
    'password': password,
    'phone': '01001234567',
    'preferredLanguage': 'ar',
    'deviceId': 'pixel-7-abc',
    'shop':
        shop ??
        {
          'name': 'صيدلية الشفاء',
          'shopType': 'Pharmacy',
          'phone': null,
          'governorate': 'القاهرة',
          'address': null,
        },
  };

  group('A1 POST /api/auth/register', () {
    test('Register_Valid_201AuthResponseAsOwner', () async {
      final response = await post(ApiPaths.authRegister, registerBody());

      expect(response.statusCode, HttpStatus.created);
      expectSameShape(json(response), fixture('auth_response'));
      final shop = json(response)['shop']! as Map<String, Object?>;
      expect(shop['role'], 'Owner');
      expect(shop['status'], 'Active');
      expect(
        response.headers.value(Headers.contentTypeHeader),
        startsWith('application/json'),
      );
    });

    test('Register_ContractExampleBody_IsAccepted', () async {
      final response = await post(
        ApiPaths.authRegister,
        fixture('register_request'),
      );

      expect(response.statusCode, HttpStatus.created);
    });

    test('Register_MissingFields_400ValidationWithLocalizedErrors', () async {
      final english = await post(ApiPaths.authRegister, <String, Object?>{});
      final arabic = await post(
        ApiPaths.authRegister,
        <String, Object?>{},
        language: 'ar',
      );

      expectProblem(english, 400, 'Validation.Failed', withErrors: true);
      final errors = json(english)['errors']! as Map<String, Object?>;
      expect(
        errors.keys,
        containsAll(['email', 'password', 'fullName', 'shop']),
      );
      final arabicErrors = json(arabic)['errors']! as Map<String, Object?>;
      expect(arabicErrors['email'], isNot(errors['email']));
    });

    test('Register_WeakPasswordOrBadEmail_400Validation', () async {
      for (final body in [
        registerBody(password: 'short1'),
        registerBody(password: 'NoDigitsHere'),
        registerBody(password: '12345678'),
        registerBody(email: 'not-an-email'),
      ]) {
        final response = await post(ApiPaths.authRegister, body);
        expectProblem(response, 400, 'Validation.Failed', withErrors: true);
      }
    });

    test(
      'Register_ShopNameBlankAfterNormalization_400ShopNameRequired',
      () async {
        final response = await post(
          ApiPaths.authRegister,
          registerBody(shop: {'name': 'ـــ', 'shopType': 'Pharmacy'}),
        );

        expectProblem(response, 400, 'Shop.NameRequired');
      },
    );

    test('Register_UnknownShopType_400ShopUnknownType', () async {
      final response = await post(
        ApiPaths.authRegister,
        registerBody(shop: {'name': 'Shop', 'shopType': 'Bakery'}),
      );

      expectProblem(response, 400, 'Shop.UnknownType');
    });

    test('Register_EmailTakenCaseInsensitive_409', () async {
      final response = await post(
        ApiPaths.authRegister,
        registerBody(email: FakeSeed.ownerEmail.toUpperCase()),
      );

      expectProblem(response, 409, 'Auth.EmailTaken');
    });
  });

  group('A2 POST /api/auth/login', () {
    test('Login_Valid_200AuthResponse', () async {
      expectSameShape(await login(), fixture('auth_response'));
      final staff = await login(email: FakeSeed.staffEmail);
      expect((staff['shop']! as Map)['role'], 'Staff');
    });

    test('Login_UnknownEmailOrWrongPassword_SameCode401', () async {
      final unknown = await post(ApiPaths.authLogin, {
        'email': 'nobody@stockly.test',
        'password': FakeSeed.password,
      });
      final wrong = await post(ApiPaths.authLogin, {
        'email': FakeSeed.ownerEmail,
        'password': 'Wrong1234',
      });

      expectProblem(unknown, 401, 'Auth.InvalidCredentials');
      expectProblem(wrong, 401, 'Auth.InvalidCredentials');
    });

    test('Login_SuspendedShop_403', () async {
      state.shops.single.status = FakeShopStatuses.suspended;

      final response = await post(ApiPaths.authLogin, {
        'email': FakeSeed.ownerEmail,
        'password': FakeSeed.password,
      });

      expectProblem(response, 403, 'Shop.Suspended');
    });

    test('Login_NoActiveMembership_403NoActiveShop', () async {
      for (final m in state.memberships) {
        m.active = false;
      }

      final response = await post(ApiPaths.authLogin, {
        'email': FakeSeed.ownerEmail,
        'password': FakeSeed.password,
      });

      expectProblem(response, 403, 'Auth.NoActiveShop');
    });

    test('Login_MissingFields_400Validation', () async {
      final response = await post(ApiPaths.authLogin, {'email': ''});

      expectProblem(response, 400, 'Validation.Failed', withErrors: true);
    });
  });

  group('A3 POST /api/auth/refresh', () {
    test('Refresh_Valid_RotatesTheRefreshToken', () async {
      final session = await login();

      final response = await post(ApiPaths.authRefresh, {
        'refreshToken': session['refreshToken'],
      });

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('auth_response'));
      expect(json(response)['refreshToken'], isNot(session['refreshToken']));
      expect(json(response)['accessToken'], isNot(session['accessToken']));
    });

    test('Refresh_RevokedTokenReused_RevokesWholeFamilyOnly', () async {
      final first = await login();
      final other = await login();
      final rotated = json(
        await post(ApiPaths.authRefresh, {
          'refreshToken': first['refreshToken'],
        }),
      );

      final reuse = await post(ApiPaths.authRefresh, {
        'refreshToken': first['refreshToken'],
      });
      final activeOfSameFamily = await post(ApiPaths.authRefresh, {
        'refreshToken': rotated['refreshToken'],
      });
      final otherLogin = await post(ApiPaths.authRefresh, {
        'refreshToken': other['refreshToken'],
      });

      expectProblem(reuse, 401, 'Auth.RefreshTokenReused');
      expectProblem(activeOfSameFamily, 401, 'Auth.RefreshTokenReused');
      expect(otherLogin.statusCode, HttpStatus.ok);
    });

    test('Refresh_UnknownOrExpired_401InvalidRefreshToken', () async {
      final unknown = await post(ApiPaths.authRefresh, {
        'refreshToken': 'nope',
      });
      final session = await login();
      clock.advance(
        FakeBackendConfig.defaultRefreshTokenLifetime +
            const Duration(seconds: 1),
      );
      final expired = await post(ApiPaths.authRefresh, {
        'refreshToken': session['refreshToken'],
      });

      expectProblem(unknown, 401, 'Auth.InvalidRefreshToken');
      expectProblem(expired, 401, 'Auth.InvalidRefreshToken');
    });

    test('Refresh_SuspendedShop_403', () async {
      final session = await login();
      state.shops.single.status = FakeShopStatuses.suspended;

      final response = await post(ApiPaths.authRefresh, {
        'refreshToken': session['refreshToken'],
      });

      expectProblem(response, 403, 'Shop.Suspended');
    });

    test('Refresh_MissingToken_400Validation', () async {
      final response = await post(ApiPaths.authRefresh, <String, Object?>{});

      expectProblem(response, 400, 'Validation.Failed', withErrors: true);
    });
  });

  group('A4 POST /api/auth/logout', () {
    test('Logout_Valid_204AndRevokesTheChain', () async {
      final session = await login();

      final response = await post(ApiPaths.authLogout, {
        'refreshToken': session['refreshToken'],
      }, token: session['accessToken']! as String);
      final refreshAfter = await post(ApiPaths.authRefresh, {
        'refreshToken': session['refreshToken'],
      });

      expect(response.statusCode, HttpStatus.noContent);
      expect(refreshAfter.statusCode, HttpStatus.unauthorized);
    });

    test('Logout_UnknownOrRevokedToken_Still204', () async {
      final session = await login();
      final token = session['accessToken']! as String;

      final unknown = await post(ApiPaths.authLogout, {
        'refreshToken': 'unknown',
      }, token: token);
      await post(ApiPaths.authLogout, {
        'refreshToken': session['refreshToken'],
      }, token: token);
      final again = await post(ApiPaths.authLogout, {
        'refreshToken': session['refreshToken'],
      }, token: token);

      expect(unknown.statusCode, HttpStatus.noContent);
      expect(again.statusCode, HttpStatus.noContent);
    });

    test('Logout_SuspendedShop_Still204', () async {
      final session = await login();
      state.shops.single.status = FakeShopStatuses.suspended;

      final response = await post(ApiPaths.authLogout, {
        'refreshToken': session['refreshToken'],
      }, token: session['accessToken']! as String);

      expect(response.statusCode, HttpStatus.noContent);
    });

    test('Logout_MissingFieldOrToken_400Or401', () async {
      final session = await login();

      final missing = await post(
        ApiPaths.authLogout,
        <String, Object?>{},
        token: session['accessToken']! as String,
      );
      final anonymous = await post(ApiPaths.authLogout, {
        'refreshToken': session['refreshToken'],
      });

      expectProblem(missing, 400, 'Validation.Failed', withErrors: true);
      expectProblem(anonymous, 401, 'Auth.Unauthenticated');
    });
  });

  group('A5 GET /api/auth/me', () {
    test('Me_Valid_200UserAndShop', () async {
      final session = await login();

      final response = await me(session['accessToken']! as String);

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('me_response'));
    });

    test('Me_ExpiredOrMissingToken_401', () async {
      final session = await login();
      clock.advance(
        FakeBackendConfig.defaultAccessTokenLifetime +
            const Duration(seconds: 1),
      );

      expectProblem(
        await me(session['accessToken']! as String),
        401,
        'Auth.Unauthenticated',
      );
      expectProblem(await me(null), 401, 'Auth.Unauthenticated');
    });

    test('Me_SuspendedShop_403', () async {
      final session = await login();
      state.shops.single.status = FakeShopStatuses.suspended;

      expectProblem(
        await me(session['accessToken']! as String),
        403,
        'Shop.Suspended',
      );
    });
  });

  group('framework errors', () {
    test('UnknownRoute_404HttpNotFound', () async {
      expectProblem(
        await dio.get<Object?>('/api/nowhere'),
        404,
        'Http.NotFound',
      );
    });

    test('WrongMethod_405HttpMethodNotAllowed', () async {
      expectProblem(
        await dio.get<Object?>(ApiPaths.authLogin),
        405,
        'Http.MethodNotAllowed',
      );
    });

    test('NonJsonBody_415HttpUnsupportedMediaType', () async {
      final response = await dio.post<Object?>(
        ApiPaths.authLogin,
        data: 'email=a',
        options: Options(contentType: Headers.textPlainContentType),
      );

      expectProblem(response, 415, 'Http.UnsupportedMediaType');
    });

    test('MalformedJson_400Validation', () async {
      final response = await dio.post<Object?>(
        ApiPaths.authLogin,
        data: '{not json',
      );

      expectProblem(response, 400, 'Validation.Failed', withErrors: true);
    });

    test('CorrelationId_EchoedFromRequest', () async {
      final response = await dio.post<Object?>(
        ApiPaths.authLogin,
        data: jsonEncode({'email': 'x'}),
        options: Options(headers: {HttpHeaderNames.correlationId: 'my-cid'}),
      );

      expect(response.headers.value('x-correlation-id'), 'my-cid');
      expect(json(response)['correlationId'], 'my-cid');
      expect(json(response)['instance'], 'POST ${ApiPaths.authLogin}');
    });
  });

  test('Latency_IsSimulated', () async {
    final slow = fakeBackend(
      clock: clock,
      state: state,
      config: const FakeBackendConfig(latency: Duration(milliseconds: 30)),
    );
    final stopwatch = Stopwatch()..start();

    await rawDio(slow).get<Object?>(
      '/api/nowhere',
      options: Options(validateStatus: (_) => true),
    );

    expect(
      stopwatch.elapsed,
      greaterThanOrEqualTo(const Duration(milliseconds: 30)),
    );
  });
}
