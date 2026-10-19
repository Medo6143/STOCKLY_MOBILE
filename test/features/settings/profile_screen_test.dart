import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/settings/presentation/providers/profile_providers.dart';
import 'package:stockly/features/settings/presentation/screens/profile_screen.dart';
import 'package:stockly/features/settings/presentation/widgets/profile_avatar.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../helpers/auth_doubles.dart';
import '../../helpers/billing_doubles.dart';
import '../../helpers/pump_app.dart';

const String _settingsMarker = 'settings-screen';
const String _privacyMarker = 'privacy-screen';

/// Design-refresh brief §4: the profile tab, 4 states × ar/en, the actions,
/// dark, RTL and reduce motion.
void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  Future<ProviderContainer> pumpProfile(
    WidgetTester tester, {
    Session? session,
    AsyncValue<Session>? value,
    ThemeMode themeMode = ThemeMode.light,
    int pending = 0,
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
          builder: (context, state) => const ProfileScreen(),
          routes: [
            GoRoute(
              path: 'settings',
              name: RouteNames.settings,
              builder: (context, state) =>
                  const Scaffold(body: Text(_settingsMarker)),
            ),
            GoRoute(
              path: 'privacy',
              name: RouteNames.privacyPolicy,
              builder: (context, state) =>
                  const Scaffold(body: Text(_privacyMarker)),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final locale = localeVariant.currentValue!;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ...authTestOverrides(repository: repository, deviceLocale: locale),
          currentSessionProvider.overrideWithValue(session),
          if (value != null) profileSessionProvider.overrideWithValue(value),
          pendingScanCountProvider.overrideWith((ref) => Stream.value(pending)),
          billingRepositoryProvider.overrideWithValue(quietBilling()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: locale,
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
    return ProviderScope.containerOf(
      tester.element(find.byType(ProfileScreen)),
    );
  }

  AppLocalizations l10n() => l10nOf(localeVariant.currentValue!);

  bool isArabic() => localeVariant.currentValue!.languageCode == 'ar';

  Finder signOut() => find.text(l10n().authSignOut);

  testWidgets('Loading_SkeletonHeader', (tester) async {
    await pumpProfile(tester, value: const AsyncLoading());

    expect(find.byType(LoadingState), findsOneWidget);
    expect(
      tester.widget<LoadingState>(find.byType(LoadingState)).shape,
      LoadingShape.profile,
    );
  }, variant: localeVariant);

  testWidgets('Empty_NotApplicable_NoSessionYetShowsTheSkeleton', (
    tester,
  ) async {
    await pumpProfile(tester);

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().authSignOut), findsNothing);
  }, variant: localeVariant);

  testWidgets('Error_SessionReadFailed_RetryRestores', (tester) async {
    when(() => repository.cachedSession()).thenAnswer((_) async => null);
    await pumpProfile(
      tester,
      value: const AsyncError(NetworkFailure(), StackTrace.empty),
    );
    await tester.pump();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorNetwork), findsOneWidget);
    await tester.tap(find.text(l10n().commonRetry));
    await tester.pumpAndSettle();
    verify(() => repository.cachedSession()).called(1);
  }, variant: localeVariant);

  testWidgets('Data_HeaderShopCardAndActions', (tester) async {
    final session = ownerSession.copyWith(
      user: ownerSession.user.copyWith(phone: '01001234567'),
    );
    await pumpProfile(tester, session: session);
    await tester.pumpAndSettle();

    final l = l10n();
    for (final text in [
      l.navProfile,
      session.user.fullName,
      ltrIsolate(session.user.email),
      ltrIsolate('01001234567'),
      l.roleOwner,
      l.settingsShop,
      session.shop.name,
      l.shopTypePharmacy,
      l.navSettings,
      l.profileSettingsSubtitle,
      l.authSignOut,
      l.profileSignOutSubtitle,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.text('م‌ع'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_NoPhone_NoPhoneLine', (tester) async {
    await pumpProfile(tester, session: ownerSession);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.phone_rounded), findsNothing);
    expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_StaffBadge', (tester) async {
    await pumpProfile(tester, session: staffSession);
    await tester.pumpAndSettle();

    expect(find.text(l10n().roleStaff), findsOneWidget);
    expect(find.text(l10n().roleOwner), findsNothing);
  }, variant: localeVariant);

  testWidgets('Settings_OpensTheSettingsScreen', (tester) async {
    await pumpProfile(tester, session: ownerSession);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n().navSettings));
    await tester.pumpAndSettle();

    expect(find.text(_settingsMarker), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('PrivacyPolicy_ActionOpensThePolicy', (tester) async {
    await pumpProfile(tester, session: ownerSession);
    await tester.pumpAndSettle();

    expect(find.text(l10n().privacyPolicySubtitle), findsOneWidget);
    await tester.tap(find.text(l10n().privacyPolicyTitle));
    await tester.pumpAndSettle();

    expect(find.text(_privacyMarker), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('SignOut_NothingPending_SignsOut', (tester) async {
    when(() => repository.logout()).thenAnswer((_) async {});
    final container = await pumpProfile(tester, session: ownerSession);
    await tester.pumpAndSettle();

    await tester.tap(signOut());
    await tester.pumpAndSettle();

    verify(() => repository.logout()).called(1);
    expect(container.read(authProvider).value, const AuthState.signedOut());
  }, variant: localeVariant);

  testWidgets('SignOut_WithPendingScans_AsksFirst', (tester) async {
    when(() => repository.logout()).thenAnswer((_) async {});
    await pumpProfile(tester, session: ownerSession, pending: 2);
    await tester.pumpAndSettle();

    await tester.tap(signOut());
    await tester.pumpAndSettle();
    expect(find.text(l10n().settingsSignOutPendingBody(2)), findsOneWidget);
    await tester.tap(find.text(l10n().commonCancel));
    await tester.pumpAndSettle();
    verifyNever(() => repository.logout());

    await tester.tap(signOut());
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n().settingsSignOutAnyway));
    await tester.pumpAndSettle();
    verify(() => repository.logout()).called(1);
  }, variant: localeVariant);

  testWidgets('SignOut_WhileRunning_ShowsTheSpinner', (tester) async {
    final logout = Completer<void>();
    when(() => repository.logout()).thenAnswer((_) => logout.future);
    await pumpProfile(tester, session: ownerSession);
    await tester.pumpAndSettle();

    await tester.tap(signOut());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    logout.complete();
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Rtl_ActionsStartOnTheReadingSide', (tester) async {
    await pumpProfile(tester, session: ownerSession);
    await tester.pumpAndSettle();

    final width = tester.view.physicalSize.width;
    final icon = tester.getCenter(find.byIcon(Icons.settings_outlined)).dx;
    final chevron = tester
        .getCenter(find.byIcon(Icons.chevron_right_rounded).first)
        .dx;
    if (isArabic()) {
      expect(icon, greaterThan(width / 2));
      expect(chevron, lessThan(width / 2));
    } else {
      expect(icon, lessThan(width / 2));
      expect(chevron, greaterThan(width / 2));
    }
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pumpProfile(tester, session: ownerSession, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(ProfileAvatar))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);

  testWidgets('ReduceMotion_FinalFrameNoTicking', (tester) async {
    await pumpProfile(tester, session: ownerSession, disableAnimations: true);
    await tester.pump();

    expect(find.text(ownerSession.user.fullName), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    expect(
      find.ancestor(
        of: find.text(l10n().authSignOut),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  }, variant: localeVariant);
}
