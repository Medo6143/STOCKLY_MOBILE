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

String? _redirect(AuthState auth, String location) =>
    authRedirect(auth, Uri.parse(location));

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
      expect(_redirect(_unknown, RoutePaths.splash), isNull);
      expect(_redirect(_unknown, '/splash?from=%2Fsettings'), isNull);
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
        RoutePaths.splash,
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
