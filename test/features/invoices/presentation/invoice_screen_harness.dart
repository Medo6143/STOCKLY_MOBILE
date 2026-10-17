import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/platform/connectivity.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/products_doubles.dart' as products;
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles.dart';

/// The mocks behind an invoice screen.
final class InvoiceMocks {
  final MockInvoicesRepository invoices = MockInvoicesRepository();
  final MockScanQueueRepository queue = MockScanQueueRepository();
  final MockInvoicePhotoSource photos = MockInvoicePhotoSource();
  final products.MockProductsRepository catalog =
      products.MockProductsRepository();
}

/// Where the screen navigated to: each target route shows its name.
const Map<String, String> _targets = {
  RouteNames.invoiceDetail: 'd/:invoiceId',
  RouteNames.invoiceReview: 'r/:invoiceId',
  RouteNames.invoiceLineEdit: 'l/:invoiceId/:lineNo',
  RouteNames.scanCapture: 'scan',
  RouteNames.scanQueue: 'queue',
};

AppLocalizations l10n() => l10nOf(localeVariant.currentValue!);

bool get isArabic => localeVariant.currentValue!.languageCode == 'ar';

/// Pumps [screen] in a router (so its navigation can be asserted) in the
/// current [localeVariant], with the invoice mocks and an Owner session.
Future<void> pumpInvoiceScreen(
  WidgetTester tester,
  Widget screen, {
  required InvoiceMocks mocks,
  ThemeMode themeMode = ThemeMode.light,
  bool online = true,
  bool disableAnimations = false,
  List<Override> overrides = const [],
  String? routeName,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: routeName,
        builder: (context, state) => screen,
        routes: [
          for (final MapEntry(key: name, value: path) in _targets.entries)
            if (name != routeName)
              GoRoute(
                path: path,
                name: name,
                builder: (context, state) => Scaffold(body: Text(name)),
              ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        invoicesRepositoryProvider.overrideWithValue(mocks.invoices),
        scanQueueRepositoryProvider.overrideWithValue(mocks.queue),
        invoicePhotoSourceProvider.overrideWithValue(mocks.photos),
        productsRepositoryProvider.overrideWithValue(mocks.catalog),
        currentSessionProvider.overrideWithValue(ownerSession),
        appLoggerProvider.overrideWithValue(const NoopLogger()),
        clockProvider.overrideWithValue(FakeClock()),
        connectivityProvider.overrideWith((ref) => Stream.value(online)),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: localeVariant.currentValue,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: app!,
        ),
      ),
    ),
  );
}

/// [finder] sits on the right half in Arabic (RTL), the left in English.
void expectLeading(WidgetTester tester, Finder finder) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final x = tester.getCenter(finder.first).dx;
  if (isArabic) {
    expect(x, greaterThan(width / 2));
  } else {
    expect(x, lessThan(width / 2));
  }
}

/// The text of the route the screen navigated to.
Finder navigatedTo(String routeName) => find.text(routeName);
