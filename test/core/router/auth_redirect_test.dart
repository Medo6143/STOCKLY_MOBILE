import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/router/auth_redirect.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/features/auth/data/models/session_mapper.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';

import '../../helpers/test_doubles.dart';

final AuthState _owner = AuthState.signedIn(
  storedSession().toEntity(),
  offline: false,
);
final AuthState _staff = AuthState.signedIn(
  storedSession(role: 'Staff').toEntity(),
  offline: true,
);
final AuthState _suspended = AuthState.suspended(storedSession().toEntity());
const AuthState _unknown = AuthState.unknown();
const AuthState _signedOut = AuthState.signedOut();

/// [splashFinished] defaults to `true`: every row below except the splash
/// gate rows describes the app after the splash minimum (design §3.2).
String? _redirect(
  AuthState auth,
  String location, {
  bool splashFinished = true,
}) => authRedirect(auth, Uri.parse(location), splashFinished: splashFinished);

void main() {
  group('authRedirect (design §3.2)', () {
    test('Unknown_AnywhereButSplash_GoesToSplashWithFrom', () {
      expect(
        _redirect(_unknown, '/products/abc'),
        '/splash?from=%2Fproducts%2Fabc',
      );
      expect(
        Uri.parse(_redirect(_unknown, '/products?lowStock=true')!)
            .queryParameters[RoutePaths.fromParameter],
        '/products?lowStock=true',
      );
      expect(_redirect(_unknown, RoutePaths.login), startsWith('/splash?'));
    });

    test('Unknown_OnSplash_Stays', () {
      for (final finished in [false, true]) {
        expect(
          _redirect(_unknown, RoutePaths.splash, splashFinished: finished),
          isNull,
        );
        expect(
          _redirect(
            _unknown,
            '/splash?from=%2Fsettings',
            splashFinished: finished,
          ),
          isNull,
        );
      }
    });

    test('Unknown_BeforeTheSplashStarted_StillGoesToSplash', () {
      expect(
        _redirect(_unknown, RoutePaths.products, splashFinished: false),
        '/splash?from=%2Fproducts',
      );
    });

    test('ResolvedSession_OnSplashBeforeTheMinimum_Stays', () {
      for (final auth in [_signedOut, _suspended, _owner, _staff]) {
        expect(
          _redirect(auth, RoutePaths.splash, splashFinished: false),
          isNull,
          reason: '$auth',
        );
        expect(
          _redirect(auth, '/splash?from=%2Fsettings', splashFinished: false),
          isNull,
          reason: '$auth',
        );
      }
    });

    test('SignedOut_OnSplashAfterTheMinimum_GoesToLogin', () {
      expect(_redirect(_signedOut, RoutePaths.splash), RoutePaths.login);
      expect(
        _redirect(_signedOut, '/splash?from=%2Fsettings'),
        RoutePaths.login,
      );
    });

    test('Suspended_OnSplashAfterTheMinimum_GoesToSuspended', () {
      expect(_redirect(_suspended, RoutePaths.splash), RoutePaths.suspended);
    });

    test('SignedIn_OnSplashAfterTheMinimum_GoesToFromOrHome', () {
      expect(_redirect(_owner, RoutePaths.splash), RoutePaths.home);
      expect(
        _redirect(_owner, '/splash?from=%2Fsettings'),
        RoutePaths.legacySettings,
      );
      expect(
        _redirect(_owner, '/splash?from=%2Fprofile%2Fsettings'),
        RoutePaths.settings,
      );
      expect(_redirect(_staff, '/splash?from=%2Flogin'), RoutePaths.home);
    });

    test('SplashGate_OnlyHoldsTheSplashRoute', () {
      expect(
        _redirect(_signedOut, RoutePaths.products, splashFinished: false),
        RoutePaths.login,
      );
      expect(
        _redirect(_suspended, RoutePaths.products, splashFinished: false),
        RoutePaths.suspended,
      );
      expect(
        _redirect(_owner, RoutePaths.login, splashFinished: false),
        RoutePaths.home,
      );
    });

    test('SignedOut_OnPublicRoute_Stays', () {
      expect(_redirect(_signedOut, RoutePaths.login), isNull);
      expect(_redirect(_signedOut, RoutePaths.register), isNull);
    });

    test('SignedOut_AnywhereElse_GoesToLogin', () {
      for (final location in [
        RoutePaths.splash,
        RoutePaths.products,
        '/invoices/123',
        RoutePaths.suspended,
        RoutePaths.settings,
      ]) {
        expect(_redirect(_signedOut, location), RoutePaths.login);
      }
    });

    test('Suspended_AnywhereButSuspended_GoesToSuspended', () {
      for (final location in [
        RoutePaths.splash,
        RoutePaths.login,
        RoutePaths.products,
        '/sales/new',
      ]) {
        expect(_redirect(_suspended, location), RoutePaths.suspended);
      }
      expect(_redirect(_suspended, RoutePaths.suspended), isNull);
    });

    test('SignedIn_OnEntryRoutes_GoesHome', () {
      for (final location in [
        RoutePaths.login,
        RoutePaths.register,
        RoutePaths.suspended,
      ]) {
        expect(_redirect(_owner, location), RoutePaths.home);
        expect(_redirect(_staff, location), RoutePaths.home);
      }
    });

    test('SignedInStaff_OwnerOnlyActions_GoToProductDetail', () {
      expect(_redirect(_staff, '/products/p1/adjust'), '/products/p1');
      expect(_redirect(_staff, '/products/p1/count'), '/products/p1');
      expect(_redirect(_staff, '/products/p1/edit'), isNull);
      expect(_redirect(_staff, '/products/p1/movements'), isNull);
      expect(_redirect(_staff, '/invoices/p1/adjust'), isNull);
    });

    test('SignedInOwner_OwnerOnlyActions_Stay', () {
      expect(_redirect(_owner, '/products/p1/adjust'), isNull);
      expect(_redirect(_owner, '/products/p1/count'), isNull);
    });

    test('SignedIn_AnythingElse_Stays', () {
      for (final location in [
        RoutePaths.products,
        '/invoices/abc/review',
        RoutePaths.settings,
        '/unknown/route',
      ]) {
        expect(_redirect(_owner, location), isNull);
      }
    });
  });

  group('splashDestination', () {
    test('FromAuthenticatedRoute_ResumesIt', () {
      expect(
        splashDestination(Uri.parse('/splash?from=%2Fproducts%2Fabc')),
        '/products/abc',
      );
      expect(
        splashDestination(
          Uri.parse(
            '/splash?from=${Uri.encodeComponent('/products?lowStock=true')}',
          ),
        ),
        '/products?lowStock=true',
      );
    });

    test('NoFromOrEntryRoute_GoesHome', () {
      for (final location in [
        '/splash',
        '/splash?from=%2Flogin',
        '/splash?from=%2Fregister',
        '/splash?from=%2Fsuspended',
        '/splash?from=%2Fsplash',
        '/splash?from=https%3A%2F%2Fevil.example',
        '/splash?from=https%3A%2F%2Fevil.example%2Fproducts',
        '/splash?from=%2F%2Fevil.example%2Fproducts',
      ]) {
        expect(splashDestination(Uri.parse(location)), RoutePaths.home);
      }
    });
  });
}
