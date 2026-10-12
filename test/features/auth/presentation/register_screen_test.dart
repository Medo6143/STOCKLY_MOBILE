import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/screens/register_screen.dart';
import 'package:stockly/features/auth/presentation/widgets/shop_type_picker.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles.dart';

/// Design §11 register: 4 states × ar/en, dark smoke, RTL.
void main() {
  late MockAuthRepository repository;

  setUpAll(registerAuthFallbacks);
  setUp(() => repository = MockAuthRepository());

  Future<ProviderContainer> pumpRegister(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    // Tall enough to build the whole form without scrolling.
    tester.view
      ..physicalSize = const Size(1080, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpLocalizedApp(
      tester,
      const RegisterScreen(),
      locale: localeVariant.currentValue!,
      themeMode: themeMode,
      overrides: authTestOverrides(
        repository: repository,
        clock: FakeClock(),
        deviceLocale: localeVariant.currentValue!,
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(RegisterScreen)),
    );
  }

  AppLocalizations l10n() => l10nOf(localeVariant.currentValue!);

  Finder field(String label) => find.widgetWithText(TextField, label);

  void answer(Future<Result<Session, Failure>> Function() result) =>
      when(() => repository.register(any())).thenAnswer((_) => result());

  Future<void> fillAndSubmit(WidgetTester tester) async {
    final l = l10n();
    await tester.enterText(field(l.authFullNameLabel), 'Mona Adel');
    await tester.enterText(field(l.authEmailLabel), 'mona@example.com');
    await tester.enterText(field(l.authPasswordLabel), 'Str0ngPass');
    await tester.enterText(field(l.authShopNameLabel), 'صيدلية الشفاء');
    await tester.tap(find.text(l.shopTypePharmacy));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  FilledButton submitButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byType(FilledButton));

  String? errorUnder(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).decoration!.errorText;

  testWidgets('Empty_BlankFormWithTheShopTypePicker', (tester) async {
    final l = l10n();
    await pumpRegister(tester);

    for (final text in [
      l.authRegisterTitle,
      l.authRegisterAboutYou,
      l.authRegisterYourShop,
      l.authFullNameLabel,
      l.authEmailLabel,
      l.authPasswordLabel,
      l.authPhoneLabel,
      l.authShopNameLabel,
      l.authShopTypeLabel,
      l.authShopPhoneLabel,
      l.authShopGovernorateLabel,
      l.authShopAddressLabel,
      l.authRegisterSubmit,
      l.authRegisterGoToLogin,
      l.shopTypePharmacy,
      l.shopTypeGrocery,
      l.shopTypeMobileShop,
      l.shopTypeOther,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byType(ChoiceChip), findsNWidgets(ShopType.values.length));
    expect(find.byType(FormBanner), findsNothing);
  }, variant: localeVariant);

  testWidgets('Empty_SubmitBlank_ShowsTheIssues', (tester) async {
    final l = l10n();
    await pumpRegister(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(errorUnder(tester, l.authFullNameLabel), l.authFieldRequired);
    expect(errorUnder(tester, l.authEmailLabel), l.authFieldRequired);
    expect(
      tester.widget<ShopTypePicker>(find.byType(ShopTypePicker)).errorText,
      l.authFieldRequired,
    );
    verifyNever(() => repository.register(any()));
  }, variant: localeVariant);

  testWidgets('Loading_SubmitSpinnerAndDisabledFields', (tester) async {
    final pending = Completer<Result<Session, Failure>>();
    answer(() => pending.future);
    await pumpRegister(tester);

    await fillAndSubmit(tester);

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.enabled, isFalse);
    }
  }, variant: localeVariant);

  testWidgets('Error_EmailTaken_UnderTheEmail', (tester) async {
    final l = l10n();
    answer(
      () async =>
          Err(ConflictFailure(ApiErrorCode.authEmailTaken, problemInfo(409))),
    );
    await pumpRegister(tester);

    await fillAndSubmit(tester);

    expect(errorUnder(tester, l.authEmailLabel), l.errorAuthEmailTaken);
  }, variant: localeVariant);

  testWidgets('Error_ShopNameAndType_UnderTheirFields', (tester) async {
    final l = l10n();
    await pumpRegister(tester);

    answer(
      () async => Err(
        InvalidInputFailure(ApiErrorCode.shopNameRequired, problemInfo(400)),
      ),
    );
    await fillAndSubmit(tester);
    expect(errorUnder(tester, l.authShopNameLabel), l.errorShopNameRequired);

    answer(
      () async => Err(
        InvalidInputFailure(ApiErrorCode.shopUnknownType, problemInfo(400)),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(
      tester.widget<ShopTypePicker>(find.byType(ShopTypePicker)).errorText,
      l.errorShopUnknownType,
    );
  }, variant: localeVariant);

  testWidgets('Error_ValidationFailed_ServerMessagesUnderFields', (
    tester,
  ) async {
    final l = l10n();
    answer(
      () async => Err(
        ValidationFailure(
          ApiErrorCode.validationFailed,
          problemInfo(400),
          fieldErrors: const {
            'password': ['server says no'],
          },
        ),
      ),
    );
    await pumpRegister(tester);

    await fillAndSubmit(tester);

    expect(errorUnder(tester, l.authPasswordLabel), 'server says no');
    expect(find.byType(FormBanner), findsNothing);
  }, variant: localeVariant);

  testWidgets('Error_RateLimited_BannerAndSubmitDisabled', (tester) async {
    final l = l10n();
    answer(() async => Err(rateLimited(const Duration(seconds: 59))));
    await pumpRegister(tester);

    await fillAndSubmit(tester);

    expect(find.text(l.authTooManyRequests(59)), findsOneWidget);
    expect(submitButton(tester).onPressed, isNull);
  }, variant: localeVariant);

  testWidgets('Data_Success_SignsInAsOwner', (tester) async {
    answer(() async => Ok(ownerSession));
    final container = await pumpRegister(tester);

    await fillAndSubmit(tester);
    await tester.pump();

    expect(
      container.read(authProvider).value,
      AuthState.signedIn(ownerSession, offline: false),
    );
    final input =
        verify(() => repository.register(captureAny())).captured.single
            as RegisterInput;
    expect(input.shopType, ShopType.pharmacy);
    expect(
      input.preferredLanguage.name,
      localeVariant.currentValue!.languageCode,
    );
  }, variant: localeVariant);

  testWidgets('Rtl_LeadingEdgeFollowsTheLanguage', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpRegister(tester);

    final width = tester.getSize(find.byType(RegisterScreen)).width;
    final section = find.text(l10n().authRegisterAboutYou);
    final firstChip = find.byType(ChoiceChip).first;
    if (locale.languageCode == 'ar') {
      expect(tester.getTopRight(section).dx, greaterThan(width * 0.8));
      expect(tester.getTopRight(firstChip).dx, greaterThan(width * 0.8));
    } else {
      expect(tester.getTopLeft(section).dx, lessThan(width * 0.2));
      expect(tester.getTopLeft(firstChip).dx, lessThan(width * 0.2));
    }
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pumpRegister(tester, themeMode: ThemeMode.dark);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(
      Theme.of(tester.element(find.byType(RegisterScreen))).brightness,
      Brightness.dark,
    );
    expect(find.text(l10n().authFieldRequired), findsWidgets);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
