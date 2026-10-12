import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/screens/login_screen.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles.dart';

/// Design §11 login: 4 states × ar/en, dark smoke, RTL.
void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  Future<ProviderContainer> pumpLogin(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpLocalizedApp(
      tester,
      const LoginScreen(),
      locale: localeVariant.currentValue!,
      themeMode: themeMode,
      overrides: authTestOverrides(
        repository: repository,
        clock: FakeClock(),
        deviceLocale: localeVariant.currentValue!,
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(LoginScreen)));
  }

  void answer(Future<Result<Session, Failure>> Function() result) => when(
    () => repository.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => result());

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'mona@stockly.test');
    await tester.enterText(find.byType(TextField).at(1), 'Stockly123');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  testWidgets('Empty_ShowsTheBlankForm', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    await pumpLogin(tester);

    expect(find.text(l10n.authLoginTitle), findsOneWidget);
    expect(find.text(l10n.authLoginSubtitle), findsOneWidget);
    expect(find.text(l10n.authEmailLabel), findsOneWidget);
    expect(find.text(l10n.authPasswordLabel), findsOneWidget);
    expect(find.text(l10n.authLoginSubmit), findsOneWidget);
    expect(find.text(l10n.authLoginGoToRegister), findsOneWidget);
    expect(find.byType(FormBanner), findsNothing);
    expect(submitButton(tester).onPressed, isNotNull);
  }, variant: localeVariant);

  testWidgets('Empty_SubmitBlank_ShowsRequiredUnderBothFields', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    await pumpLogin(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(find.text(l10n.authFieldRequired), findsNWidgets(2));
  }, variant: localeVariant);

  testWidgets('Loading_SubmitSpinnerAndDisabledFields', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    final pending = Completer<Result<Session, Failure>>();
    answer(() => pending.future);
    await pumpLogin(tester);

    await fillAndSubmit(tester);

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(l10n.commonLoading), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
  }, variant: localeVariant);

  testWidgets('Error_InvalidCredentials_UnderThePassword', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    answer(() async => const Err(invalidCredentials));
    await pumpLogin(tester);

    await fillAndSubmit(tester);

    final password = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(password.decoration!.errorText, l10n.errorAuthInvalidCredentials);
    expect(find.byType(FormBanner), findsNothing);
  }, variant: localeVariant);

  testWidgets('Error_LockedOut_MinutesLeftAndFormStaysUsable', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    answer(() async => Err(lockedOut(const Duration(seconds: 841))));
    await pumpLogin(tester);

    await fillAndSubmit(tester);

    expect(find.byType(FormBanner), findsOneWidget);
    expect(find.text(l10n.authLockedOut(15)), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  }, variant: localeVariant);

  testWidgets('Error_RateLimited_SecondsLeftAndSubmitDisabled', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    answer(() async => Err(rateLimited(const Duration(seconds: 30))));
    await pumpLogin(tester);

    await fillAndSubmit(tester);

    expect(find.text(l10n.authTooManyRequests(30)), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  }, variant: localeVariant);

  testWidgets('Error_SuspendedNoShopOrNetwork_Banner', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    await pumpLogin(tester);
    for (final (failure, message) in [
      (
        ShopSuspendedFailure(ApiErrorCode.shopSuspended, problemInfo(403)),
        l10n.errorShopSuspended,
      ),
      (
        ForbiddenFailure(ApiErrorCode.authNoActiveShop, problemInfo(403)),
        l10n.errorAuthNoActiveShop,
      ),
      (const NetworkFailure(), l10n.errorNetwork),
    ]) {
      answer(() async => Err(failure));

      await fillAndSubmit(tester);

      expect(
        find.descendant(
          of: find.byType(FormBanner),
          matching: find.text(message),
        ),
        findsOneWidget,
      );
    }
  }, variant: localeVariant);

  testWidgets('Error_SessionEndedBeforeLogin_ShowsWhy', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    final container = await pumpLogin(tester);

    container.read(sessionSignalsProvider).sessionEnded(sessionEnded);
    await tester.pump();

    expect(find.text(l10n.errorSessionEnded), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_Success_SignsIn', (tester) async {
    answer(() async => Ok(ownerSession));
    final container = await pumpLogin(tester);

    await fillAndSubmit(tester);
    await tester.pump();

    expect(
      container.read(authProvider).value,
      AuthState.signedIn(ownerSession, offline: false),
    );
  }, variant: localeVariant);

  testWidgets('Rtl_LeadingEdgeFollowsTheLanguage', (tester) async {
    final locale = localeVariant.currentValue!;
    final l10n = l10nOf(locale);
    await pumpLogin(tester);

    final width = tester.getSize(find.byType(LoginScreen)).width;
    final title = find.text(l10n.authLoginTitle);
    if (locale.languageCode == 'ar') {
      expect(tester.getTopRight(title).dx, greaterThan(width * 0.8));
      expect(tester.getTopLeft(title).dx, greaterThan(width * 0.2));
    } else {
      expect(tester.getTopLeft(title).dx, lessThan(width * 0.2));
    }
    expect(
      Directionality.of(tester.element(title)),
      locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    );
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    answer(() async => const Err(invalidCredentials));
    await pumpLogin(tester, themeMode: ThemeMode.dark);

    await fillAndSubmit(tester);

    expect(
      Theme.of(tester.element(find.byType(LoginScreen))).brightness,
      Brightness.dark,
    );
    expect(find.text(l10n.errorAuthInvalidCredentials), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
