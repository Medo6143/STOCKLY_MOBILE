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
import 'package:stockly/l10n/generated/app_localizations.dart';

import 'auth_doubles.dart';
import 'pump_app.dart';
import 'test_doubles.dart';

/// Where a dashboard or sales screen can navigate: each target route
/// shows its name and the location it was opened with.
const Map<String, String> _targets = {
  RouteNames.products: 'products',
  RouteNames.productCreate: 'products-new',
  RouteNames.invoices: 'invoices',
  RouteNames.invoiceDetail: 'invoice/:invoiceId',
  RouteNames.scanCapture: 'scan',
  RouteNames.expiringSoon: 'expiring',
  RouteNames.sales: 'sales',
  RouteNames.quickSale: 'quick-sale',
  RouteNames.saleDetail: 'sale/:saleId',
};

AppLocalizations routedL10n() => l10nOf(localeVariant.currentValue!);

bool get routedIsArabic => localeVariant.currentValue!.languageCode == 'ar';

/// Pumps [screen] at `/` of a router in the current [localeVariant], with
/// an Owner session, no network checks and the given [overrides].
Future<void> pumpRoutedScreen(
  WidgetTester tester,
  Widget screen, {
  required List<Override> overrides,
  ThemeMode themeMode = ThemeMode.light,
  bool online = true,
  bool disableAnimations = false,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => screen,
        routes: [
          for (final MapEntry(key: name, value: path) in _targets.entries)
            GoRoute(
              path: path,
              name: name,
              builder: (context, state) => Scaffold(
                body: Column(
                  children: [Text(name), Text(state.uri.toString())],
                ),
              ),
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
      ),
    ),
  );
}

/// The screen navigated to [routeName].
Finder routedTo(String routeName) => find.text(routeName);

/// [finder] sits on the right half in Arabic (RTL), the left in English.
void expectStartSide(WidgetTester tester, Finder finder) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final x = tester.getCenter(finder.first).dx;
  if (routedIsArabic) {
    expect(x, greaterThan(width / 2));
  } else {
    expect(x, lessThan(width / 2));
  }
}
