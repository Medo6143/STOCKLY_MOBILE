import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/core/storage/stored_session.dart';

import 'scripted_adapter.dart';
import 'test_app.dart';

/// A small API for tests that run the whole app: sign-in for an owner and a
/// staff member, token refresh with rotation, and a contract fixture
/// (`test/fixtures/contract`) for every read the screens make. It replaces
/// the fake backend in the published tests; it keeps no stock, invoices or
/// sales of its own.
final class TestServer {
  new({this.suspended = false});

  static const String ownerEmail = 'owner@stockly.test';
  static const String staffEmail = 'staff@stockly.test';
  static const String password = 'Stockly123';

  static const String shopId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d9f';

  /// An invoice the server reports as confirmed, failed or needing review.
  static const String confirmedInvoiceId =
      '0192f0a0-6c1e-7b3a-9d2e-1a7e00000001';
  static const String failedInvoiceId = '0192f0a0-6c1e-7b3a-9d2e-1a7e00000002';
  static const String needsReviewInvoiceId =
      '0192f0a0-6c1e-7b3a-9d2e-1a7e00000003';

  /// The shop is suspended: login, refresh and `me` answer
  /// `403 Shop.Suspended`, logout still works (contract §1.4).
  bool suspended;

  late final ScriptedAdapter adapter = ScriptedAdapter(_serve);

  final Map<String, String> _roleOfRefresh = {};
  final Set<String> _validAccess = {};
  final Set<String> _revokedRefresh = {};
  final Set<String> _registered = {ownerEmail, staffEmail};
  int _issued = 0;

  /// The refresh tokens revoked by logout or reuse.
  Set<String> get revokedRefreshTokens => _revokedRefresh;

  /// Every access token issued so far stops working (it expired); refresh
  /// tokens still work.
  void expireAccessTokens() => _validAccess.clear();

  Future<ResponseBody> _serve(RequestOptions options) async {
    switch (options.path) {
      case ApiPaths.authLogin:
        return _login(_body(options));
      case ApiPaths.authRegister:
        return _register(_body(options));
      case ApiPaths.authRefresh:
        return _refresh(_body(options));
      case ApiPaths.authLogout:
        _revokedRefresh.add('${_body(options)['refreshToken']}');
        return ResponseBody.fromString('', HttpStatus.noContent);
    }
    final role = _authorized(options);
    if (role == null) {
      return problemBody(HttpStatus.unauthorized, 'Auth.Unauthenticated');
    }
    if (options.path == ApiPaths.authMe) {
      return suspended
          ? problemBody(HttpStatus.forbidden, 'Shop.Suspended')
          : jsonBody(HttpStatus.ok, _me(role));
    }
    final fixture = _fixtureFor(options);
    return fixture == null
        ? problemBody(HttpStatus.notFound, 'Http.NotFound')
        : jsonBody(HttpStatus.ok, fixture);
  }

  ResponseBody _login(Map<String, Object?> body) {
    final email = '${body['email']}';
    if (!_registered.contains(email) || body['password'] != password) {
      return problemBody(HttpStatus.unauthorized, 'Auth.InvalidCredentials');
    }
    if (suspended) {
      return problemBody(HttpStatus.forbidden, 'Shop.Suspended');
    }
    return jsonBody(HttpStatus.ok, _session(email, _roleOf(email)));
  }

  ResponseBody _register(Map<String, Object?> body) {
    final email = '${body['email']}';
    if (_registered.contains(email)) {
      return problemBody(HttpStatus.conflict, 'Auth.EmailTaken');
    }
    _registered.add(email);
    final session = _session(email, 'Owner');
    final shop = body['shop'] as Map<String, Object?>? ?? const {};
    return jsonBody(HttpStatus.created, {
      ...session,
      'user': {
        ...session['user']! as Map<String, Object?>,
        'preferredLanguage': body['preferredLanguage'] ?? 'ar',
      },
      'shop': {
        ...session['shop']! as Map<String, Object?>,
        'shopType': shop['shopType'] ?? 'Pharmacy',
      },
    });
  }

  ResponseBody _refresh(Map<String, Object?> body) {
    final token = '${body['refreshToken']}';
    final role = _roleOfRefresh[token];
    if (role == null) {
      return problemBody(HttpStatus.unauthorized, 'Auth.InvalidRefreshToken');
    }
    if (_revokedRefresh.contains(token)) {
      return problemBody(HttpStatus.unauthorized, 'Auth.RefreshTokenReused');
    }
    if (suspended) {
      return problemBody(HttpStatus.forbidden, 'Shop.Suspended');
    }
    _revokedRefresh.add(token);
    final email = role == 'Staff' ? staffEmail : ownerEmail;
    return jsonBody(HttpStatus.ok, _session(email, role));
  }

  /// The role of the caller's valid access token, or `null`.
  String? _authorized(RequestOptions options) {
    if (options.extra[RequestExtras.anonymous] == true) {
      return null;
    }
    final header = '${options.headers[HttpHeaderNames.authorization]}';
    final token = header.replaceFirst(HttpHeaderNames.bearerPrefix, '');
    if (!_validAccess.contains(token)) {
      return null;
    }
    return token.startsWith('staff-') ? 'Staff' : 'Owner';
  }

  Map<String, Object?> _session(String email, String role) {
    _issued++;
    final prefix = role == 'Staff' ? 'staff' : 'owner';
    final access = '$prefix-access-$_issued';
    final refresh = '$prefix-refresh-$_issued';
    _validAccess.add(access);
    _roleOfRefresh[refresh] = role;
    final response = _fixture('auth_response');
    return {
      ...response,
      'accessToken': access,
      'refreshToken': refresh,
      'user': {...response['user']! as Map<String, Object?>, 'email': email},
      'shop': _shop(role),
    };
  }

  Map<String, Object?> _me(String role) {
    final me = _fixture('me_response');
    return {...me, 'shop': _shop(role)};
  }

  Map<String, Object?> _shop(String role) => {
    ..._fixture('me_response')['shop']! as Map<String, Object?>,
    'id': shopId,
    'status': suspended ? 'Suspended' : 'Active',
    'role': role,
  };

  static String _roleOf(String email) =>
      email == staffEmail ? 'Staff' : 'Owner';

  /// The fixture of a read, with the id of the path where it has one.
  Object? _fixtureFor(RequestOptions options) {
    if (options.method != 'GET') {
      return null;
    }
    final segments = Uri.parse(options.path).pathSegments;
    final path = options.path;
    return switch (path) {
      ApiPaths.dashboardSummary => _fixture('dashboard_summary'),
      ApiPaths.dashboardExpiringSoon => _onePage('expiring_page'),
      ApiPaths.products => _onePage('product_list_page'),
      ApiPaths.productLookup => _fixture('product_lookup_response'),
      ApiPaths.invoices => _onePage('invoice_page'),
      ApiPaths.sales => _onePage('sale_list_page'),
      ApiPaths.billingPlans => [_fixture('billing_plan')],
      ApiPaths.billingSubscription => _fixture('subscription_summary'),
      ApiPaths.billingPayments => _onePage('payment_page'),
      _ when path.endsWith('/movements') => _onePage('movement_page'),
      _ when segments.length == 3 && path.startsWith(ApiPaths.products) => {
        ..._fixture('product_detail'),
        'id': segments[2],
      },
      _ when segments.length == 3 && path.startsWith(ApiPaths.invoices) =>
        _invoice(segments[2]),
      _ when segments.length == 3 && path.startsWith(ApiPaths.sales) => {
        ..._fixture('sale'),
        'id': segments[2],
      },
      _
          when segments.length == 4 &&
              path.startsWith(ApiPaths.billingPayments) =>
        {..._fixture('payment'), 'id': segments[3]},
      _ => null,
    };
  }

  /// A page fixture as the whole list: some fixtures announce more items
  /// than they hold, and asking for the next page would repeat them.
  static Map<String, Object?> _onePage(String name) {
    final page = _fixture(name);
    return {...page, 'totalCount': (page['items']! as List<Object?>).length};
  }

  Map<String, Object?> _invoice(String id) => {
    ..._fixture('invoice_detail'),
    'id': id,
    'status': switch (id) {
      confirmedInvoiceId => 'Confirmed',
      failedInvoiceId => 'Failed',
      _ => 'NeedsReview',
    },
  };

  static Map<String, Object?> _body(RequestOptions options) {
    final data = options.data;
    return switch (data) {
      final Map<String, Object?> map => map,
      final String text => jsonDecode(text) as Map<String, Object?>,
      _ => const {},
    };
  }

  static Map<String, Object?> _fixture(String name) =>
      jsonDecode(File('test/fixtures/contract/$name.json').readAsStringSync())
          as Map<String, Object?>;
}

/// Signs in on [adapter] (a [TestServer]'s) and returns the session to store.
Future<StoredSession> signIn(
  HttpClientAdapter adapter, {
  String email = TestServer.ownerEmail,
}) async {
  final response = await rawDio(adapter).post<Object?>(
    ApiPaths.authLogin,
    data: {'email': email, 'password': TestServer.password},
    options: Options(extra: {RequestExtras.anonymous: true}),
  );
  return StoredSession.fromAuthResponse(
    AuthResponseDto.fromJson(requireJsonObject(response.data)),
  );
}
