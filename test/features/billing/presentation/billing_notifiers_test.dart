import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/platform/external_browser.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/billing/domain/entities/billing_timings.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/domain/entities/wallet_phone_rules.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/billing/presentation/providers/checkout_notifier.dart';
import 'package:stockly/features/billing/presentation/providers/payment_status_notifier.dart';
import 'package:stockly/features/billing/presentation/providers/payment_status_state.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';

import '../../../helpers/billing_doubles.dart';
import '../../../helpers/dashboard_doubles.dart';
import '../../../helpers/test_doubles.dart';

/// Plans-payments brief: the checkout per method, `clientRequestId` kept
/// on a retry and new for a new attempt, the B4 polling that stops on a
/// final status and on dispose, the resume refresh and the cancel.
void main() {
  late MockBillingRepository billing;
  late RecordingBrowser browser;
  late CountingUuidGenerator uuid;

  setUpAll(registerBillingFallbacks);
  setUp(() {
    billing = quietBilling();
    browser = RecordingBrowser();
    uuid = CountingUuidGenerator();
  });

  /// Widget tests dispose it themselves, before the pending-timer check.
  ProviderContainer container({
    bool disposeInTearDown = true,
    ExternalBrowser? externalBrowser,
  }) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        billingRepositoryProvider.overrideWithValue(billing),
        externalBrowserProvider.overrideWithValue(externalBrowser ?? browser),
        uuidGeneratorProvider.overrideWithValue(uuid),
        clockProvider.overrideWithValue(FakeClock()),
        appLoggerProvider.overrideWithValue(const NoopLogger()),
        dashboardRepositoryProvider.overrideWithValue(quietDashboard()),
      ],
    );
    if (disposeInTearDown) {
      addTearDown(c.dispose);
    }
    return c;
  }

  List<CheckoutRequest> sent() =>
      verify(() => billing.checkout(captureAny())).captured
          .cast<CheckoutRequest>();

  group('CheckoutNotifier', () {
    void answer(Result<Payment, Failure> Function() result) =>
        when(() => billing.checkout(any())).thenAnswer((_) async => result());

    test('Card_OpensTheHostedPage_PaymentSet', () async {
      answer(() => Ok(payment()));
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});

      await c
          .read(checkoutProvider(basicPlanId).notifier)
          .submit(walletPhone: '');

      expect(sub.read().payment, payment());
      expect(browser.opened, [Uri.parse(checkoutUrl)]);
      final request = sent().single;
      expect(request.method, PaymentMethod.card);
      expect(request.walletPhone, isNull);
      expect(request.planId, basicPlanId);
    });

    test('SlowBrowser_PaymentShownBeforeTheBrowserAnswers', () async {
      // The payment exists on the server: the sheet must move on even when
      // the browser takes long or never comes back.
      answer(() => Ok(payment()));
      final slow = SlowBrowser();
      final c = container(externalBrowser: slow);
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});

      final submitting = c
          .read(checkoutProvider(basicPlanId).notifier)
          .submit(walletPhone: '');
      await pumpEventQueue();

      expect(sub.read().payment, payment());
      expect(sub.read().isSubmitting, isFalse);
      slow.answer.complete(true);
      await submitting;
    });

    test('Kiosk_NoBrowser', () async {
      answer(() => Ok(payment(method: PaymentMethod.kiosk)));
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});
      final notifier = c.read(checkoutProvider(basicPlanId).notifier)
        ..selectMethod(PaymentMethod.kiosk);

      await notifier.submit(walletPhone: '');

      expect(sub.read().payment?.method, PaymentMethod.kiosk);
      expect(browser.opened, isEmpty);
      expect(sent().single.method, PaymentMethod.kiosk);
    });

    test('Wallet_BadPhoneNotSent_ArabicDigitsNormalized', () async {
      answer(() => Ok(payment(method: PaymentMethod.wallet)));
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});
      final notifier = c.read(checkoutProvider(basicPlanId).notifier)
        ..selectMethod(PaymentMethod.wallet);

      await notifier.submit(walletPhone: '');
      expect(sub.read().phoneIssue, WalletPhoneIssue.required);
      await notifier.submit(walletPhone: '0131234567');
      expect(sub.read().phoneIssue, WalletPhoneIssue.invalid);
      verifyNever(() => billing.checkout(any()));
      notifier.phoneChanged();
      expect(sub.read().phoneIssue, isNull);

      await notifier.submit(walletPhone: '٠١٠١٢٣٤٥٦٧٨');

      expect(sent().single.walletPhone, '01012345678');
      expect(browser.opened, hasLength(1));
    });

    test('Retry_SameAttemptKeepsTheId', () async {
      var calls = 0;
      when(() => billing.checkout(any())).thenAnswer(
        (_) async =>
            calls++ == 0 ? const Err(providerUnavailable) : Ok(payment()),
      );
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});
      final notifier = c.read(checkoutProvider(basicPlanId).notifier);

      await notifier.submit(walletPhone: '');
      expect(sub.read().failure, providerUnavailable);
      expect(sub.read().isSubmitting, isFalse);
      await notifier.submit(walletPhone: '');

      final requests = sent();
      expect(requests, hasLength(2));
      expect(requests.first.clientRequestId, requests.last.clientRequestId);
      expect(uuid.count, 1);
    });

    test('NewAttempt_NewMethodOrNewSheet_NewId', () async {
      answer(() => const Err(NetworkFailure()));
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});
      final notifier = c.read(checkoutProvider(basicPlanId).notifier);

      await notifier.submit(walletPhone: '');
      notifier.selectMethod(PaymentMethod.kiosk);
      await notifier.submit(walletPhone: '');
      sub.close();
      await pumpEventQueue();
      final again = c.listen(checkoutProvider(basicPlanId), (_, _) {});
      await c
          .read(checkoutProvider(basicPlanId).notifier)
          .submit(walletPhone: '');
      again.close();

      final ids = sent().map((r) => r.clientRequestId).toList();
      expect(ids, hasLength(3));
      expect(ids.toSet(), hasLength(3));
    });

    test('ValidationOnWalletPhone_UnderTheField', () async {
      answer(
        () => const Err(
          ValidationFailure(
            ApiErrorCode.validationFailed,
            ApiProblemInfo(status: 400),
            fieldErrors: {
              'walletPhone': ['رقم غلط'],
            },
          ),
        ),
      );
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});
      final notifier = c.read(checkoutProvider(basicPlanId).notifier)
        ..selectMethod(PaymentMethod.wallet);

      await notifier.submit(walletPhone: '01012345678');

      expect(sub.read().phoneMessages, ['رقم غلط']);
      expect(sub.read().failure, isNull);
    });

    test('PaymentPending_OffersThePendingPayment', () async {
      answer(() => const Err(paymentPending));
      when(billing.getSubscription).thenAnswer(
        (_) async => Ok(subscriptionSummary(pendingPayment: payment())),
      );
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});

      await c
          .read(checkoutProvider(basicPlanId).notifier)
          .submit(walletPhone: '');
      await pumpEventQueue();

      expect(sub.read().failure, paymentPending);
      expect(sub.read().pendingPaymentId, paymentId);
    });

    test('Forbidden_InTheBanner', () async {
      answer(() => const Err(billingForbidden));
      final c = container();
      final sub = c.listen(checkoutProvider(basicPlanId), (_, _) {});

      await c
          .read(checkoutProvider(basicPlanId).notifier)
          .submit(walletPhone: '');

      expect(sub.read().failure, billingForbidden);
      expect(sub.read().payment, isNull);
    });
  });

  group('PaymentStatusNotifier', () {
    testWidgets('Polls_StopsOnAFinalStatus', (tester) async {
      final answers = [payment(), payment(status: PaymentStatus.paid)];
      var calls = 0;
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => Ok(answers[calls++]));
      final c = container(disposeInTearDown: false);
      final sub = c.listen(paymentStatusProvider(paymentId), (_, _) {});

      await tester.pump();
      expect(sub.read().payment?.status, PaymentStatus.pending);
      expect(sub.read().polling, isTrue);
      await tester.pump(PaymentPolling.interval);

      expect(sub.read().payment?.status, PaymentStatus.paid);
      expect(sub.read().polling, isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 2);
      sub.close();
      c.dispose();
    });

    testWidgets('OpenCheckout_NoBrowser_SaysSoUntilItOpens', (tester) async {
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => Ok(payment()));
      browser.opens = false;
      final c = container(disposeInTearDown: false);
      final sub = c.listen(paymentStatusProvider(paymentId), (_, _) {});
      await tester.pump();
      final notifier = c.read(paymentStatusProvider(paymentId).notifier);

      await notifier.openCheckout();
      expect(browser.opened, [Uri.parse(checkoutUrl)]);
      expect(sub.read().pageNotOpened, isTrue);

      browser.opens = true;
      await notifier.openCheckout();
      expect(sub.read().pageNotOpened, isFalse);
      sub.close();
      c.dispose();
    });

    testWidgets('Disposed_NoMorePolls', (tester) async {
      var calls = 0;
      when(() => billing.getPayment(paymentId)).thenAnswer((_) async {
        calls++;
        return Ok(payment());
      });
      final c = container(disposeInTearDown: false);
      final sub = c.listen(paymentStatusProvider(paymentId), (_, _) {});
      await tester.pump();

      sub.close();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 30));

      expect(calls, 1);
      c.dispose();
    });

    testWidgets('PauseThenResume_PollsAgain', (tester) async {
      var calls = 0;
      when(() => billing.getPayment(paymentId)).thenAnswer((_) async {
        calls++;
        return Ok(payment());
      });
      final c = container(disposeInTearDown: false);
      final sub = c.listen(paymentStatusProvider(paymentId), (_, _) {});
      final notifier = c.read(paymentStatusProvider(paymentId).notifier);
      await tester.pump();

      notifier.pause();
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 1);
      expect(sub.read().waitingWithoutPolling, isTrue);
      notifier.refresh();
      await tester.pump();

      expect(calls, 2);
      expect(sub.read().polling, isTrue);
      sub.close();
      c.dispose();
    });

    testWidgets('FirstPollFails_ErrorView_ThenData', (tester) async {
      final answers = <Result<Payment, Failure>>[
        const Err(paymentNotFound),
        Ok(payment()),
      ];
      var calls = 0;
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => answers[calls++]);
      final c = container(disposeInTearDown: false);
      final sub = c.listen(paymentStatusProvider(paymentId), (_, _) {});
      expect(sub.read().view, isA<AsyncLoading<Payment>>());

      await tester.pump();
      expect(sub.read().view, isA<AsyncError<Payment>>());
      await tester.pump(PaymentPolling.interval);

      expect(sub.read().view.value, payment());
      expect(sub.read().failure, isNull);
      sub.close();
      c.dispose();
    });

    testWidgets('Cancel_ExpiredAndStopped_FailureKeepsPolling', (tester) async {
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => Ok(payment()));
      final answers = <Result<Payment, Failure>>[
        const Err(notCancelable),
        Ok(payment(status: PaymentStatus.expired)),
      ];
      var cancels = 0;
      when(() => billing.cancelPayment(paymentId))
          .thenAnswer((_) async => answers[cancels++]);
      final c = container(disposeInTearDown: false);
      final sub = c.listen(paymentStatusProvider(paymentId), (_, _) {});
      final notifier = c.read(paymentStatusProvider(paymentId).notifier);
      await tester.pump();

      await notifier.cancel();
      expect(sub.read().cancelFailure, notCancelable);
      expect(sub.read().polling, isTrue);
      await tester.pump();
      await notifier.cancel();

      expect(sub.read().payment?.status, PaymentStatus.expired);
      expect(sub.read().polling, isFalse);
      expect(sub.read().cancelling, isFalse);
      sub.close();
      c.dispose();
    });

    testWidgets('OpenCheckout_OnlyForAPendingHostedPayment', (tester) async {
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => Ok(payment()));
      final c = container(disposeInTearDown: false);
      final sub = c.listen(paymentStatusProvider(paymentId), (_, _) {});
      await tester.pump();

      await c.read(paymentStatusProvider(paymentId).notifier).openCheckout();

      expect(browser.opened, [Uri.parse(checkoutUrl)]);
      sub.close();
      c.dispose();
    });
  });
}
