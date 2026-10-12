import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';

/// The overrides of a product screen test: a mocked repository and the
/// session that decides Owner or Staff.
List<Override> productOverrides(
  MockProductsRepository repository, {
  Session? session,
}) => [
  productsRepositoryProvider.overrideWithValue(repository),
  currentSessionProvider.overrideWithValue(session ?? ownerSession),
  appLoggerProvider.overrideWithValue(const NoopLogger()),
];

/// Pumps [screen] in the current [localeVariant] with a tall view so the
/// whole form or list is laid out.
Future<void> pumpProductScreen(
  WidgetTester tester,
  Widget screen, {
  required MockProductsRepository repository,
  Session? session,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpLocalizedApp(
    tester,
    screen,
    locale: localeVariant.currentValue!,
    themeMode: themeMode,
    overrides: productOverrides(repository, session: session),
  );
}

/// Pumps a router app at [location], for tests that follow a navigation.
Future<void> pumpProductRouter(
  WidgetTester tester, {
  required String location,
  required List<RouteBase> routes,
  required MockProductsRepository repository,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 2600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: location, routes: routes);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: productOverrides(repository),
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: router,
        locale: localeVariant.currentValue,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
      ),
    ),
  );
}

/// The localizations of the current variant.
AppLocalizations l10n() => l10nOf(localeVariant.currentValue!);

bool get isArabic => localeVariant.currentValue!.languageCode == 'ar';

/// The error text under the field labelled [label].
String? fieldError(WidgetTester tester, String label) => tester
    .widget<TextField>(
      find.ancestor(of: find.text(label), matching: find.byType(TextField)),
    )
    .decoration
    ?.errorText;

/// Enters [text] in the field labelled [label].
Future<void> enterField(WidgetTester tester, String label, String text) =>
    tester.enterText(
      find.ancestor(of: find.text(label), matching: find.byType(TextField)),
      text,
    );

/// Asserts the leading edge follows the language: [finder] sits on the
/// right half in Arabic (RTL) and on the left half in English.
void expectLeading(WidgetTester tester, Finder finder) {
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  final x = tester.getCenter(finder.first).dx;
  if (isArabic) {
    expect(x, greaterThan(width / 2));
  } else {
    expect(x, lessThan(width / 2));
  }
}
