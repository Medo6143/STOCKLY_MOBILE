import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/app.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';
import 'package:stockly/core/router/app_router.dart';
import 'package:stockly/core/router/home_shell.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/widgets/error_state.dart';
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
import 'package:stockly/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:stockly/features/settings/presentation/screens/profile_screen.dart';
import 'package:stockly/features/settings/presentation/screens/settings_screen.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_doubles.dart';
import '../../helpers/test_server.dart';

Future<ProviderContainer> _startApp(
  WidgetTester tester, {
  required InMemoryTokenStorage tokens,
  required TestServer server,
  Locale deviceLocale = const Locale('ar'),
  AppDatabase? database,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: appOverrides(
        adapter: server.adapter,
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

/// The user, product and unit of the contract fixtures (`auth_response`,
/// `product_detail`).
const String _userId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d9e';
const String _productId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d9e';
const String _unitId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8da1';

/// How far each drag scrolls while looking for a link below the fold.
const double _scrollStep = 300;

String _location(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<InMemoryTokenStorage> _signedInTokens(
  TestServer server, {
  String email = TestServer.ownerEmail,
}) async => InMemoryTokenStorage(await signIn(server.adapter, email: email));

void main() {
  testWidgets('NoStoredSession_StartsOnLogin', (tester) async {
    final container = await _startApp(
      tester,
      tokens: InMemoryTokenStorage(),
      server: TestServer(),
    );

    expect(_location(container), RoutePaths.login);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(container.read(authProvider).value, isA<AuthSignedOut>());
  });

  testWidgets('StoredSession_StartsOnHomeBehindTheRedirect', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));

    final container = await _startApp(tester, tokens: tokens!, server: server);

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
      l10n.navProfile,
    ]) {
      expect(find.text(label), findsWidgets);
    }
    final auth = container.read(authProvider).value! as AuthSignedIn;
    expect(auth.offline, isFalse);
  });

  testWidgets('SuspendedShop_StartsOnSuspended', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    server.suspended = true;

    final container = await _startApp(tester, tokens: tokens!, server: server);

    expect(_location(container), RoutePaths.suspended);
    expect(container.read(authProvider).value, isA<AuthSuspended>());
  });

  testWidgets('Staff_OwnerOnlyRoute_RedirectsToProduct', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(
      () => _signedInTokens(server, email: TestServer.staffEmail),
    );
    final container = await _startApp(tester, tokens: tokens!, server: server);

    container.read(routerProvider).go('/products/p1/adjust');
    await tester.pumpAndSettle();

    expect(_location(container), '/products/p1');
  });

  testWidgets('UnknownRoute_ShowsNotFoundWithGoHome', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(
      tester,
      tokens: tokens!,
      server: server,
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
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);
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
      expect(find.byType(ErrorState), findsNothing, reason: location);
    }
  });

  testWidgets('PendingSaleAtStart_ReopensTheQuickSaleLocked', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final database = inMemoryDatabase();
    const id = '0192f0a0-6c1e-7b3a-9d2e-5a1e00000002';
    await tester.runAsync(
      () => database.pendingSalesDao.insertSale(
        PendingSalesCompanion.insert(
          clientRequestId: id,
          shopId: TestServer.shopId,
          userId: _userId,
          requestJson:
              '{"clientRequestId":"$id","note":null,"items":[{"productId":'
              '"$_productId","productUnitId":"$_unitId",'
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
      server: server,
      database: database,
    );

    expect(_location(container), RoutePaths.quickSale);
    expect(find.byType(QuickSaleScreen), findsOneWidget);
    final l10n = l10nOf(const Locale('ar'));
    expect(find.text(l10n.salesLockedTitle), findsOneWidget);
  });

  testWidgets('SprintThreeScreens_ReplaceTheirPlaceholders', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);

    container.read(routerProvider).go(RoutePaths.settings);
    await tester.pumpAndSettle();

    expect(_location(container), RoutePaths.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('BottomNav_FiveTabsInOrder', (tester) async {
    for (final locale in [const Locale('ar'), const Locale('en')]) {
      final server = TestServer();
      final tokens = await tester.runAsync(() => _signedInTokens(server));
      await _startApp(
        tester,
        tokens: tokens!,
        server: server,
        deviceLocale: locale,
      );

      final l10n = l10nOf(locale);
      final labels = tester
          .widgetList<NavigationDestination>(find.byType(NavigationDestination))
          .map((destination) => destination.label)
          .toList();
      expect(labels, [
        l10n.navDashboard,
        l10n.navProducts,
        l10n.navInvoices,
        l10n.navSales,
        l10n.navProfile,
      ], reason: locale.languageCode);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('ProfileTab_OpensTheProfileAndItsSettings', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);
    final l10n = l10nOf(const Locale('ar'));

    await tester.tap(find.text(l10n.navProfile));
    await tester.pumpAndSettle();
    expect(_location(container), RoutePaths.profile);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(DashboardScreen), findsNothing);
    expect(
      find.byType(DashboardScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'the left tab keeps its state, offstage',
    );

    // The plan card sits above the actions; scroll down to settings.
    await tester.scrollUntilVisible(
      find.text(l10n.navSettings),
      _scrollStep,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text(l10n.navSettings));
    await tester.pumpAndSettle();
    expect(_location(container), RoutePaths.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('LegacySettings_RedirectsToProfileSettings', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);

    container.read(routerProvider).go(RoutePaths.legacySettings);
    await tester.pumpAndSettle();

    expect(_location(container), RoutePaths.settings);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('PrivacyPolicy_OpenSignedOutFromRegister', (tester) async {
    final container = await _startApp(
      tester,
      tokens: InMemoryTokenStorage(),
      server: TestServer(),
    );
    container.read(routerProvider).go(RoutePaths.register);
    await tester.pumpAndSettle();

    final l10n = l10nOf(const Locale('ar'));
    await tester.scrollUntilVisible(
      find.text(l10n.privacyPolicyTitle),
      _scrollStep,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.privacyPolicyTitle));
    await tester.pumpAndSettle();

    // Pushed over the current page.
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsNothing);
    expect(_location(container), RoutePaths.register);
  });

  testWidgets('PrivacyPolicy_OpenSignedInFromProfile', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);
    container.read(routerProvider).go(RoutePaths.profile);
    await tester.pumpAndSettle();

    final l10n = l10nOf(const Locale('ar'));
    await tester.scrollUntilVisible(
      find.text(l10n.privacyPolicyTitle),
      _scrollStep,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.privacyPolicyTitle));
    await tester.pumpAndSettle();

    // Pushed over the current page.
    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyPolicyScreen), findsNothing);
    expect(_location(container), RoutePaths.profile);
  });

  testWidgets('ProductRoutes_RenderTheProductScreens', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);
    const id = _productId;
    const unitId = _unitId;

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
      expect(find.byType(ErrorState), findsNothing, reason: location);
    }
  });

  testWidgets('InvoiceRoutes_RenderTheInvoiceScreens', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);
    const confirmed = TestServer.confirmedInvoiceId;
    const review = TestServer.needsReviewInvoiceId;

    for (final (location, screen) in [
      ('/invoices', InvoiceListScreen),
      ('/invoices?status=NeedsReview', InvoiceListScreen),
      ('/invoices/scan', ScanCaptureScreen),
      ('/invoices/queue', ScanQueueScreen),
      ('/invoices/$confirmed', InvoiceDetailScreen),
      ('/invoices/${TestServer.failedInvoiceId}', InvoiceDetailScreen),
      ('/invoices/$review/review', InvoiceReviewScreen),
      ('/invoices/$review/review/lines/1', InvoiceLineEditorScreen),
    ]) {
      container.read(routerProvider).go(location);
      await tester.pumpAndSettle();
      expect(_location(container), location);
      expect(find.byType(screen), findsOneWidget, reason: location);
      expect(find.byType(ErrorState), findsNothing, reason: location);
    }
  });

  testWidgets('NeedsReviewDetail_OpensTheReview', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);
    const review = TestServer.needsReviewInvoiceId;

    container.read(routerProvider).go('/invoices/$review');
    await tester.pumpAndSettle();

    expect(_location(container), '/invoices/$review/review');
    expect(find.byType(InvoiceReviewScreen), findsOneWidget);
  });

  testWidgets('BadLineNumber_ShowsNotFound', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);

    container
        .read(routerProvider)
        .go('/invoices/${TestServer.needsReviewInvoiceId}/review/lines/x');
    await tester.pumpAndSettle();

    expect(find.byType(NotFoundScreen), findsOneWidget);
  });

  testWidgets('Logout_ReturnsToLogin', (tester) async {
    final server = TestServer();
    final tokens = await tester.runAsync(() => _signedInTokens(server));
    final container = await _startApp(tester, tokens: tokens!, server: server);

    await tester.runAsync(() => container.read(authProvider.notifier).logout());
    await tester.pumpAndSettle();

    expect(_location(container), RoutePaths.login);
    expect(tokens.session, isNull);
  });
}
