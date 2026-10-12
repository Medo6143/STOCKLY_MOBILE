import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Every widget test runs in Arabic (RTL) and English (LTR).
final ValueVariant<Locale> localeVariant = ValueVariant<Locale>({
  const Locale('ar'),
  const Locale('en'),
});

/// Pumps [child] in a localized, themed app.
Future<void> pumpLocalizedApp(
  WidgetTester tester,
  Widget child, {
  required Locale locale,
  ThemeMode themeMode = ThemeMode.light,
  List<Override> overrides = const [],
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp(
        locale: locale,
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
        home: Scaffold(body: child),
      ),
    ),
  );
}

/// The localizations of [locale], for asserting texts without literals.
AppLocalizations l10nOf(Locale locale) => lookupAppLocalizations(locale);
