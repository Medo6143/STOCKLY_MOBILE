import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/preferences/theme_mode_notifier.dart';
import 'package:stockly/core/router/app_router.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The app: router, light and dark themes, Arabic (RTL) and English.
class StocklyApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    routerConfig: ref.watch(routerProvider),
    onGenerateTitle: (context) => AppLocalizations.of(context).appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: ref.watch(themeModeProvider),
    locale: ref.watch(localeProvider),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}
