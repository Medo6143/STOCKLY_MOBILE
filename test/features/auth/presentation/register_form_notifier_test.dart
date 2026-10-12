import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/providers/register_form_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/register_form_state.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/test_doubles.dart';

const RegisterDraft _draft = RegisterDraft(
  fullName: ' Mona Adel ',
  email: ' mona@example.com ',
  password: 'Str0ngPass',
  phone: '01001234567',
  shopName: ' صيدلية الشفاء ',
  shopGovernorate: 'القاهرة',
);

void main() {
  late MockAuthRepository repository;
  late FakeClock clock;
  late ProviderContainer container;

  setUpAll(registerAuthFallbacks);

  setUp(() {
    repository = MockAuthRepository();
    clock = FakeClock();
  });

  ProviderContainer build({Locale device = const Locale('ar')}) =>
      ProviderContainer.test(
        overrides: authTestOverrides(
          repository: repository,
          clock: clock,
          deviceLocale: device,
        ),
      )..listen(registerFormProvider, (_, _) {});

  void answer(Result<Session, Failure> result) =>
      when(() => repository.register(any())).thenAnswer((_) async => result);

  RegisterFormState form() => container.read(registerFormProvider);

  Future<void> submit([RegisterDraft draft = _draft]) =>
      container.read(registerFormProvider.notifier).submit(draft);

  void pickPharmacy() => container
      .read(registerFormProvider.notifier)
      .selectShopType(ShopType.pharmacy);

  test('build_StartsBlankWithoutShopType', () {
    container = build();
    expect(form(), const RegisterFormState());
  });

  test('submit_NoShopTypeAndBadFields_ShowsIssuesAndSendsNothing', () async {
    container = build();

    await submit(
      const RegisterDraft(
        fullName: '',
        email: 'nope',
        password: 'short',
        shopName: '',
      ),
    );

    expect(form().issues, {
      AuthField.fullName: AuthFieldIssue.required,
      AuthField.email: AuthFieldIssue.invalidEmail,
      AuthField.password: AuthFieldIssue.weakPassword,
      AuthField.shopName: AuthFieldIssue.required,
      AuthField.shopType: AuthFieldIssue.required,
    });
    verifyNever(() => repository.register(any()));
  });

  test('selectShopType_ClearsTheShopTypeIssue', () async {
    container = build();
    await submit();
    expect(form().issues[AuthField.shopType], AuthFieldIssue.required);

    pickPharmacy();

    expect(form().shopType, ShopType.pharmacy);
    expect(form().issues, isEmpty);
  });

  test('submit_Success_SendsTrimmedInputWithAppLanguageAndSignsIn', () async {
    container = build(device: const Locale('en'));
    answer(Ok(ownerSession));
    pickPharmacy();

    await submit();

    final input =
        verify(() => repository.register(captureAny())).captured.single
            as RegisterInput;
    expect(
      input,
      const RegisterInput(
        fullName: 'Mona Adel',
        email: 'mona@example.com',
        password: 'Str0ngPass',
        preferredLanguage: AppLanguage.en,
        shopName: 'صيدلية الشفاء',
        shopType: ShopType.pharmacy,
        phone: '01001234567',
        shopGovernorate: 'القاهرة',
      ),
    );
    expect(
      container.read(authProvider).requireValue,
      AuthState.signedIn(ownerSession, offline: false),
    );
  });

  test('submit_EmailTakenShopNameShopType_UnderTheirFields', () async {
    container = build();
    pickPharmacy();
    for (final (code, field, status) in const [
      (ApiErrorCode.authEmailTaken, AuthField.email, 409),
      (ApiErrorCode.shopNameRequired, AuthField.shopName, 400),
      (ApiErrorCode.shopUnknownType, AuthField.shopType, 400),
    ]) {
      final failure = code == ApiErrorCode.authEmailTaken
          ? ConflictFailure(code, ApiProblemInfo(status: status))
          : InvalidInputFailure(code, ApiProblemInfo(status: status));
      answer(Err(failure));

      await submit();

      expect(form().fieldFailures, {field: failure}, reason: code.wire);
      expect(form().failure, isNull);
      expect(form().shopType, ShopType.pharmacy);
    }
  });

  test('submit_ValidationFailed_UnknownKeyAlsoShowsTheBanner', () async {
    container = build();
    pickPharmacy();
    const failure = ValidationFailure(
      ApiErrorCode.validationFailed,
      ApiProblemInfo(status: 400),
      fieldErrors: {
        'shop.name': ['too long'],
        'deviceId': ['too long'],
      },
    );
    answer(const Err(failure));

    await submit();

    expect(form().serverErrors, {
      AuthField.shopName: ['too long'],
    });
    expect(form().failure, failure);
  });

  testWidgets('submit_RateLimited_BlocksSubmitUntilRetryAfter', (tester) async {
    container = build();
    pickPharmacy();
    answer(Err(rateLimited(const Duration(seconds: 2))));

    await submit();
    expect(form().canSubmit, isFalse);
    expect(form().retryAfterRemaining, const Duration(seconds: 2));

    clock.advance(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    expect(form().canSubmit, isTrue);
    expect(form().failure, isNull);
  });
}
