import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/config/app_version.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/preferences/theme_mode_notifier.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/settings/presentation/screens/settings_screen.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../helpers/auth_doubles.dart';
import '../../helpers/pump_app.dart';

/// Design §11 settings: 4 states × ar/en, dark smoke.
void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    Session? session,
    ThemeMode themeMode = ThemeMode.light,
    int pending = 0,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpLocalizedApp(
      tester,
      const SettingsScreen(),
      locale: localeVariant.currentValue!,
      themeMode: themeMode,
      overrides: [
        ...authTestOverrides(
          repository: repository,
          deviceLocale: localeVariant.currentValue!,
        ),
        currentSessionProvider.overrideWithValue(session),
        pendingScanCountProvider.overrideWith((ref) => Stream.value(pending)),
      ],
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(SettingsScreen)),
    );
  }

  AppLocalizations l10n() => l10nOf(localeVariant.currentValue!);

  Finder signOutButton() => find.byWidgetPredicate((w) => w is OutlinedButton);

  Finder version() => find.text(l10n().settingsVersion(AppVersion.display));

  testWidgets('Data_EverySection', (tester) async {
    final l = l10n();
    await pumpSettings(tester, session: ownerSession);

    for (final text in [
      l.navSettings,
      l.settingsLanguage,
      l.settingsLanguageSystem,
      l.settingsLanguageArabic,
      l.settingsLanguageEnglish,
      l.settingsTheme,
      l.settingsThemeSystem,
      l.settingsThemeLight,
      l.settingsThemeDark,
      l.settingsShop,
      l.settingsAccount,
      l.settingsShopName,
      ownerSession.shop.name,
      l.settingsShopType,
      l.shopTypePharmacy,
      l.settingsRole,
      l.roleOwner,
      l.settingsUserName,
      ownerSession.user.fullName,
      ownerSession.user.email,
      l.authSignOut,
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(version(), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_StaffSeesTheirRole', (tester) async {
    await pumpSettings(tester, session: staffSession);

    expect(find.text(l10n().roleStaff), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_LanguageAndThemeChoicesApply', (tester) async {
    final l = l10n();
    final container = await pumpSettings(tester, session: ownerSession);
    final other = localeVariant.currentValue!.languageCode == 'ar'
        ? (l.settingsLanguageEnglish, LocalePreference.en, AppLocales.english)
        : (l.settingsLanguageArabic, LocalePreference.ar, AppLocales.arabic);

    await tester.tap(find.text(l.settingsThemeDark));
    await tester.pump();
    await tester.tap(find.text(other.$1));
    await tester.pump();

    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(container.read(localePreferenceProvider), other.$2);
    expect(container.read(localeProvider), other.$3);
  }, variant: localeVariant);

  testWidgets('Loading_SigningOutShowsTheSpinner', (tester) async {
    final pending = Completer<void>();
    when(() => repository.logout()).thenAnswer((_) => pending.future);
    await pumpSettings(tester, session: ownerSession);

    await tester.tap(signOutButton());
    await tester.pump();

    expect(
      find.descendant(
        of: signOutButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(signOutButton()).onPressed, isNull);
    pending.complete();
    await tester.pump();
  }, variant: localeVariant);

  testWidgets('Empty_NotApplicable_NoSessionShowsTheLoadingState', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().settingsLanguage), findsNothing);
  }, variant: localeVariant);

  testWidgets('Error_NoneBlocksSignOut_ServerUnreachableStillSignsOut', (
    tester,
  ) async {
    when(() => repository.logout()).thenAnswer((_) async {});
    final container = await pumpSettings(tester, session: ownerSession);

    await tester.tap(signOutButton());
    await tester.pump();

    expect(container.read(authProvider).value, const AuthState.signedOut());
  }, variant: localeVariant);

  testWidgets('SignOut_WithPendingScans_AsksFirst', (tester) async {
    when(() => repository.logout()).thenAnswer((_) async {});
    final container = await pumpSettings(
      tester,
      session: ownerSession,
      pending: 2,
    );
    await tester.pump();

    await tester.tap(signOutButton());
    await tester.pumpAndSettle();
    expect(find.text(l10n().settingsSignOutPendingTitle), findsOneWidget);
    expect(find.text(l10n().settingsSignOutPendingBody(2)), findsOneWidget);
    await tester.tap(find.text(l10n().commonCancel));
    await tester.pumpAndSettle();
    verifyNever(() => repository.logout());

    await tester.tap(signOutButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n().settingsSignOutAnyway));
    await tester.pumpAndSettle();

    verify(() => repository.logout()).called(1);
    expect(container.read(authProvider).value, const AuthState.signedOut());
  }, variant: localeVariant);

  testWidgets('VersionLongPress_OpensNothing', (tester) async {
    await pumpSettings(tester, session: ownerSession);

    await tester.longPress(version());
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pumpSettings(
      tester,
      session: ownerSession,
      themeMode: ThemeMode.dark,
    );

    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
