import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/providers/login_form_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/login_form_state.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/test_doubles.dart';

/// Timing tests run in `testWidgets`: its fake time fires the countdown.
void main() {
  late MockAuthRepository repository;
  late FakeClock clock;
  late ProviderContainer container;

  ProviderContainer build({Locale device = const Locale('ar')}) {
    final created = ProviderContainer.test(
      overrides: authTestOverrides(
        repository: repository,
        clock: clock,
        deviceLocale: device,
      ),
    )..listen(loginFormProvider, (_, _) {});
    return created;
  }

  setUp(() {
    repository = MockAuthRepository();
    clock = FakeClock();
  });

  void answer(Result<Session, Failure> result) => when(
    () => repository.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) async => result);

  LoginFormState form() => container.read(loginFormProvider);

  Future<void> submit({
    String email = ' mona@stockly.test ',
    String password = 'Stockly123',
  }) => container
      .read(loginFormProvider.notifier)
      .submit(email: email, password: password);

  Future<void> elapse(WidgetTester tester, Duration by) {
    clock.advance(by);
    return tester.pump(by);
  }

  test('build_StartsBlank', () {
    container = build();
    expect(form(), const LoginFormState());
    expect(form().canSubmit, isTrue);
  });

  test('submit_BlankFields_ShowsIssuesAndSendsNothing', () async {
    container = build();

    await submit(email: '', password: '');

    expect(form().issues, {
      AuthField.email: AuthFieldIssue.required,
      AuthField.password: AuthFieldIssue.required,
    });
    verifyNever(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('submit_Success_SignsInWithTrimmedEmail', () async {
    container = build();
    answer(Ok(ownerSession));

    await submit();

    expect(
      container.read(authProvider).requireValue,
      AuthState.signedIn(ownerSession, offline: false),
    );
    expect(form(), const LoginFormState());
    verify(
      () =>
          repository.login(email: 'mona@stockly.test', password: 'Stockly123'),
    ).called(1);
  });

  test('submit_Success_AdoptsThePreferredLanguageOnce', () async {
    container = build(device: const Locale('en'));
    answer(Ok(ownerSession));

    await submit();

    expect(container.read(localeProvider), AppLocales.arabic);
    expect(container.read(localePreferenceProvider), LocalePreference.ar);
  });

  test('submit_WhileSubmitting_IsLoading', () async {
    container = build();
    final pending = Completer<Result<Session, Failure>>();
    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) => pending.future);

    final running = submit();

    expect(form().isSubmitting, isTrue);
    expect(form().canSubmit, isFalse);
    pending.complete(const Err(NetworkFailure()));
    await running;
    expect(form().isSubmitting, isFalse);
    expect(form().failure, const NetworkFailure());
  });

  test('submit_InvalidCredentials_ShownUnderThePassword', () async {
    container = build();
    answer(const Err(invalidCredentials));

    await submit();

    expect(form().fieldFailures, {AuthField.password: invalidCredentials});
    expect(form().failure, isNull);
  });

  test('submit_ValidationFailed_FieldMessagesUnderFields', () async {
    container = build();
    const failure = ValidationFailure(
      ApiErrorCode.validationFailed,
      ApiProblemInfo(status: 400),
      fieldErrors: {
        'email': ['bad email'],
      },
    );
    answer(const Err(failure));

    await submit();

    expect(form().serverErrors, {
      AuthField.email: ['bad email'],
    });
    expect(form().failure, isNull);
  });

  test('submit_SuspendedOrNoActiveShop_Banner', () async {
    container = build();
    for (final failure in [
      const ShopSuspendedFailure(
        ApiErrorCode.shopSuspended,
        ApiProblemInfo(status: 403),
      ),
      const ForbiddenFailure(
        ApiErrorCode.authNoActiveShop,
        ApiProblemInfo(status: 403),
      ),
    ]) {
      answer(Err(failure));
      await submit();
      expect(form().failure, failure);
    }
  });

  testWidgets('submit_LockedOut_CountsDownAndKeepsTheFormUsable', (
    tester,
  ) async {
    container = build();
    final locked = lockedOut(const Duration(minutes: 15));
    answer(Err(locked));

    await submit();

    expect(form().failure, locked);
    expect(form().lockoutRemaining, const Duration(minutes: 15));
    expect(form().canSubmit, isTrue);

    await elapse(tester, const Duration(minutes: 5));
    expect(form().lockoutRemaining, const Duration(minutes: 10));

    await elapse(tester, const Duration(minutes: 10));
    expect(form().lockoutRemaining, isNull);
    expect(form().failure, isNull);
  });

  testWidgets('submit_RateLimited_BlocksSubmitUntilRetryAfter', (tester) async {
    container = build();
    final limited = rateLimited(const Duration(seconds: 3));
    answer(Err(limited));

    await submit();
    expect(form().retryAfterRemaining, const Duration(seconds: 3));
    expect(form().canSubmit, isFalse);

    await submit();
    verify(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).called(1);

    await elapse(tester, const Duration(seconds: 1));
    expect(form().retryAfterRemaining, const Duration(seconds: 2));

    await elapse(tester, const Duration(seconds: 2));
    expect(form().retryAfterRemaining, isNull);
    expect(form().failure, isNull);
    expect(form().canSubmit, isTrue);
  });

  testWidgets('submit_AfterLockout_StopsTheOldCountdown', (tester) async {
    container = build();
    answer(Err(lockedOut(const Duration(minutes: 1))));
    await submit();
    answer(const Err(invalidCredentials));

    await submit();
    await elapse(tester, const Duration(minutes: 2));

    expect(form().lockoutRemaining, isNull);
    expect(form().fieldFailures, {AuthField.password: invalidCredentials});
  });
}
