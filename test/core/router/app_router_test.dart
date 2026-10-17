import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/app.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/seed/fake_invoice_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_product_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';
import 'package:stockly/core/router/app_router.dart';
import 'package:stockly/core/router/home_shell.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/widgets/not_found_screen.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/screens/login_screen.dart';
import 'package:stockly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:stockly/features/dashboard/presentation/screens/expiring_soon_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_detail_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_line_editor_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_list_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_review_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/scan_capture_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/scan_queue_screen.dart';
import 'package:stockly/features/products/presentation/screens/movement_list_screen.dart';
import 'package:stockly/features/products/presentation/screens/product_detail_screen.dart';
import 'package:stockly/features/products/presentation/screens/product_form_screen.dart';
import 'package:stockly/features/products/presentation/screens/product_list_screen.dart';
import 'package:stockly/features/products/presentation/screens/stock_adjustment_screen.dart';
import 'package:stockly/features/products/presentation/screens/stock_count_screen.dart';
import 'package:stockly/features/products/presentation/screens/unit_form_screen.dart';
import 'package:stockly/features/sales/presentation/screens/quick_sale_screen.dart';
import 'package:stockly/features/sales/presentation/screens/sale_detail_screen.dart';
import 'package:stockly/features/sales/presentation/screens/sale_list_screen.dart';
import 'package:stockly/features/settings/presentation/screens/settings_screen.dart';

import '../../helpers/fake_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles.dart';

Future<ProviderContainer> _startApp(
  WidgetTester tester, {
  required InMemoryTokenStorage tokens,
  required FakeBackendState state,
  Locale deviceLocale = const Locale('ar'),
  AppDatabase? database,
}) async {
  final adapter = fakeBackend(state: state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: fakeAppOverrides(
        adapter: adapter,
        tokens: tokens,
        deviceLocale: deviceLocale,
        database: database,
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
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(container.read(authProvider).value, isA<AuthSignedOut>());
  });

  testWidgets('StoredSession_StartsOnHomeBehindTheRedirect', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));

    final container = await _startApp(tester, tokens: tokens!, state: state);

    expect(_location(container), RoutePaths.dashboard);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    final l10n = l10nOf(const Locale('ar'));
    for (final label in [
      l10n.navDashboard,
      l10n.navProducts,
      l10n.navInvoices,
      l10n.navSales,
      l10n.navSettings,
    ]) {
      expect(find.text(label), findsWidgets);
    }
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

  testWidgets('SprintFourRoutes_RenderTheirScreens', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);
    const sale = '0192f0a0-6c1e-7b3a-9d2e-5a1e00000001';

    for (final (location, screen) in [
      ('/dashboard', DashboardScreen),
      ('/dashboard/expiring-soon', ExpiringSoonScreen),
      ('/dashboard/expiring-soon?days=30', ExpiringSoonScreen),
      ('/sales', SaleListScreen),
      ('/sales/new', QuickSaleScreen),
      ('/sales/$sale', SaleDetailScreen),
    ]) {
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
      expect(_location(container), location);
      expect(find.byType(NotFoundScreen), findsNothing, reason: location);
      expect(find.byType(screen), findsOneWidget, reason: location);
    }
  });

  testWidgets('PendingSaleAtStart_ReopensTheQuickSaleLocked', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final database = inMemoryDatabase();
    const id = '0192f0a0-6c1e-7b3a-9d2e-5a1e00000002';
    final product = state.products.firstWhere(
      (p) => p.barcode == FakeProductSeed.panadolBarcode,
    );
    await tester.runAsync(
      () => database.pendingSalesDao.insertSale(
        PendingSalesCompanion.insert(
          clientRequestId: id,
          shopId: state.shops.single.id,
          userId: state.users.first.id,
          requestJson:
              '{"clientRequestId":"$id","note":null,"items":[{"productId":'
              '"${product.id}","productUnitId":"${product.baseUnit.id}",'
              '"quantity":"1.000","unitPrice":null}]}',
          status: PendingSaleStatus.awaitingRetry,
          createdAt: DateTime.utc(2026, 10, 12, 7),
          updatedAt: DateTime.utc(2026, 10, 12, 7),
        ),
      ),
    );

    final container = await _startApp(
      tester,
      tokens: tokens!,
      state: state,
      database: database,
    );

    expect(_location(container), RoutePaths.quickSale);
    expect(find.byType(QuickSaleScreen), findsOneWidget);
    final l10n = l10nOf(const Locale('ar'));
    expect(find.text(l10n.salesLockedTitle), findsOneWidget);
  });

  testWidgets('SprintThreeScreens_ReplaceTheirPlaceholders', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);

    container.read(routerProvider).go(RoutePaths.settings);
    await tester.pumpAndSettle();

    expect(_location(container), RoutePaths.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('ProductRoutes_RenderTheProductScreens', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);
    final product = state.products.first;
    final id = product.id;
    final unitId = product.units.last.id;

    for (final (location, screen) in [
      ('/products', ProductListScreen),
      ('/products?lowStock=true', ProductListScreen),
      ('/products/new', ProductFormScreen),
      ('/products/$id', ProductDetailScreen),
      ('/products/$id/edit', ProductFormScreen),
      ('/products/$id/units/new', UnitFormScreen),
      ('/products/$id/units/$unitId/edit', UnitFormScreen),
      ('/products/$id/adjust', StockAdjustmentScreen),
      ('/products/$id/count', StockCountScreen),
      ('/products/$id/movements', MovementListScreen),
    ]) {
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
      expect(_location(container), location);
      expect(find.byType(screen), findsOneWidget, reason: location);
    }
  });

  testWidgets('InvoiceRoutes_RenderTheInvoiceScreens', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);
    const confirmed = FakeInvoiceSeed.confirmedId;
    const review = FakeInvoiceSeed.needsReviewId;

    for (final (location, screen) in [
      ('/invoices', InvoiceListScreen),
      ('/invoices?status=NeedsReview', InvoiceListScreen),
      ('/invoices/scan', ScanCaptureScreen),
      ('/invoices/queue', ScanQueueScreen),
      ('/invoices/$confirmed', InvoiceDetailScreen),
      ('/invoices/${FakeInvoiceSeed.failedId}', InvoiceDetailScreen),
      ('/invoices/$review/review', InvoiceReviewScreen),
      ('/invoices/$review/review/lines/2', InvoiceLineEditorScreen),
    ]) {
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
      expect(_location(container), location);
      expect(find.byType(screen), findsOneWidget, reason: location);
    }
  });

  testWidgets('NeedsReviewDetail_OpensTheReview', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);
    const review = FakeInvoiceSeed.needsReviewId;

    container.read(routerProvider).go('/invoices/$review');
    await tester.pumpAndSettle();

    expect(_location(container), '/invoices/$review/review');
    expect(find.byType(InvoiceReviewScreen), findsOneWidget);
  });

  testWidgets('BadLineNumber_ShowsNotFound', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await tester.runAsync(() => _signedInTokens(state));
    final container = await _startApp(tester, tokens: tokens!, state: state);

    container
        .read(routerProvider)
        .go('/invoices/${FakeInvoiceSeed.needsReviewId}/review/lines/x');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
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
