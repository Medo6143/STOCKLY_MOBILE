import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/app.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/router/app_router.dart';
import 'package:stockly/core/router/home_shell.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/widgets/not_found_screen.dart';
import 'package:stockly/core/widgets/placeholder_screen.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';

import '../../helpers/fake_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles.dart';

Future<ProviderContainer> _startApp(
  WidgetTester tester, {
  required InMemoryTokenStorage tokens,
  required FakeBackendState state,
  Locale deviceLocale = const Locale('ar'),
}) async {
  final adapter = fakeBackend(state: state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: fakeAppOverrides(
        adapter: adapter,
        tokens: tokens,
        deviceLocale: deviceLocale,
      ),
      retry: (_, _) => null,
      child: const StocklyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(StocklyApp)));
}

String _location(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<InMemoryTokenStorage> _signedInTokens(
  FakeBackendState state, {
  String email = FakeSeed.ownerEmail,
}) async => InMemoryTokenStorage(
  await loginOn(fakeBackend(state: state), email: email),
);

void main() {
  testWidgets('NoStoredSession_StartsOnLogin', (tester) async {
    final container = await _startApp(
      tester,
      tokens: InMemoryTokenStorage(),
      state: FakeSeed.pharmacy(FakeClock().now()),
    );

    expect(_location(container), RoutePaths.login);
    expect(find.byType(PlaceholderScreen), findsOneWidget);
    expect(container.read(authProvider).value, isA<AuthSignedOut>());
  });

  testWidgets('StoredSession_StartsOnHomeBehindTheRedirect', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));

    final container = await _startApp(tester, tokens: tokens!, state: state);

    expect(_location(container), RoutePaths.home);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    final l10n = l10nOf(const Locale('ar'));
    expect(find.text(l10n.navProducts), findsWidgets);
    final auth = container.read(authProvider).value! as AuthSignedIn;
    expect(auth.offline, isFalse);
  });

  testWidgets('SuspendedShop_StartsOnSuspended', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    state.shops.single.status = FakeShopStatuses.suspended;

    final container = await _startApp(tester, tokens: tokens!, state: state);

    expect(_location(container), RoutePaths.suspended);
    expect(container.read(authProvider).value, isA<AuthSuspended>());
  });

  testWidgets('Staff_OwnerOnlyRoute_RedirectsToProduct', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(
      () => _signedInTokens(state, email: FakeSeed.staffEmail),
    );
    final container = await _startApp(tester, tokens: tokens!, state: state);

    container.read(routerProvider).go('/products/p1/adjust');
    await tester.pumpAndSettle();

    expect(_location(container), '/products/p1');
  });

  testWidgets('UnknownRoute_ShowsNotFoundWithGoHome', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(
      tester,
      tokens: tokens!,
      state: state,
      deviceLocale: const Locale('en'),
    );

    container.read(routerProvider).go('/nowhere');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
    final l10n = l10nOf(const Locale('en'));
    await tester.tap(find.text(l10n.commonGoHome));
    await tester.pumpAndSettle();
    expect(_location(container), RoutePaths.home);
  });

  testWidgets('EveryDeclaredRoute_RendersAPlaceholderWhenSignedIn', (
    tester,
  ) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);

    for (final location in [
      '/dashboard',
      '/dashboard/expiring-soon',
      '/products',
      '/products/new',
      '/products/p1',
      '/products/p1/edit',
      '/products/p1/units/new',
      '/products/p1/units/u1/edit',
      '/products/p1/adjust',
      '/products/p1/count',
      '/products/p1/movements',
      '/invoices',
      '/invoices/scan',
      '/invoices/queue',
      '/invoices/i1',
      '/invoices/i1/review',
      '/invoices/i1/review/lines/2',
      '/sales',
      '/sales/new',
      '/sales/s1',
      '/settings',
    ]) {
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
      expect(_location(container), location);
      expect(find.byType(NotFoundScreen), findsNothing, reason: location);
      expect(find.byType(PlaceholderScreen), findsWidgets, reason: location);
    }
  });

  testWidgets('Logout_ReturnsToLogin', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);

    await tester.runAsync(() => container.read(authProvider.notifier).logout());
    await tester.pumpAndSettle();

    expect(_location(container), RoutePaths.login);
    expect(tokens.session, isNull);
  });
}
