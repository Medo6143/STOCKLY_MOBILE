import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/billing_timings.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/domain/entities/wallet_phone_rules.dart';
import 'package:stockly/features/billing/domain/usecases/cancel_payment_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/checkout_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_payment_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_payments_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_plans_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/get_subscription_use_case.dart';
import 'package:stockly/features/billing/domain/usecases/watch_payment_use_case.dart';

import '../../../helpers/billing_doubles.dart';

/// Plans-payments brief: wallet phone rules, the 80 % quota warning, the
/// checkout request and the B4 polling.
void main() {
  late MockBillingRepository billing;

  setUpAll(registerBillingFallbacks);
  setUp(() => billing = MockBillingRepository());

  group('WalletPhoneRules', () {
    test('EgyptianMobiles_Valid', () {
      for (final phone in [
        '01012345678',
        '01112345678',
        '01212345678',
        '01512345678',
        ' 010 1234 5678 ',
        '010-1234-5678',
      ]) {
        expect(WalletPhoneRules.check(phone), isNull, reason: phone);
      }
    });

    test('ArabicIndicAndPersianDigits_NormalizedAndValid', () {
      expect(WalletPhoneRules.normalize('٠١٠١٢٣٤٥٦٧٨'), '01012345678');
      expect(WalletPhoneRules.normalize('۰۱۱۱۲۳۴۵۶۷۸'), '01112345678');
      expect(WalletPhoneRules.check('٠١٥ ١٢٣٤ ٥٦٧٨'), isNull);
    });

    test('EmptyRequired_OthersInvalid', () {
      expect(WalletPhoneRules.check('  '), WalletPhoneIssue.required);
      for (final phone in [
        '01312345678',
        '0101234567',
        '010123456789',
        '+201012345678',
        '02012345678',
        'abc',
      ]) {
        expect(
          WalletPhoneRules.check(phone),
          WalletPhoneIssue.invalid,
          reason: phone,
        );
      }
    });
  });

  group('SubscriptionSummary', () {
    test('NearQuota_From80Percent', () {
      expect(subscriptionSummary(scansToday: 39).isNearQuota, isFalse);
      expect(subscriptionSummary(scansToday: 40).isNearQuota, isTrue);
      expect(subscriptionSummary(scansToday: 60).isNearQuota, isTrue);
      expect(subscriptionSummary(scansToday: 0, quota: 0).isNearQuota, isTrue);
    });

    test('ScanUsage_Between0And1', () {
      expect(subscriptionSummary(scansToday: 25).scanUsage, 0.5);
      expect(subscriptionSummary(scansToday: 70).scanUsage, 1);
      expect(subscriptionSummary(scansToday: 0, quota: 0).scanUsage, 1);
    });
  });

  test('Plan_CheckOutOnlyPaidAndNotCurrent', () {
    final plans = billingPlans();
    expect(plans.map((p) => p.canCheckOut), [false, true, true]);
    expect(billingPlan(isCurrent: true).canCheckOut, isFalse);
  });

  test('Payment_HostedPageOnlyWhilePending', () {
    expect(payment().openableCheckoutUrl, Uri.parse(checkoutUrl));
    expect(payment(method: PaymentMethod.kiosk).openableCheckoutUrl, isNull);
    expect(payment(status: PaymentStatus.paid).openableCheckoutUrl, isNull);
    expect(PaymentStatus.values.where((s) => !s.isFinal), [
      PaymentStatus.pending,
    ]);
    expect(PaymentMethod.kiosk.usesHostedPage, isFalse);
    expect(PaymentMethod.wallet.usesHostedPage, isTrue);
  });

  test('CheckoutRequest_SameAttempt', () {
    const request = CheckoutRequest(
      clientRequestId: paymentRequestId,
      planId: basicPlanId,
      method: PaymentMethod.wallet,
      walletPhone: '01012345678',
    );
    expect(
      request.sameAttemptAs(
        planId: basicPlanId,
        method: PaymentMethod.wallet,
        walletPhone: '01012345678',
      ),
      isTrue,
    );
    expect(
      request.sameAttemptAs(
        planId: basicPlanId,
        method: PaymentMethod.wallet,
        walletPhone: '01112345678',
      ),
      isFalse,
    );
    expect(
      request.sameAttemptAs(
        planId: proPlanId,
        method: PaymentMethod.wallet,
        walletPhone: '01012345678',
      ),
      isFalse,
    );
  });

  group('Use cases', () {
    test('Checkout_WalletPhoneNormalized_DroppedForOtherMethods', () async {
      when(() => billing.checkout(any()))
          .thenAnswer((_) async => Ok(payment()));
      final checkout = CheckoutUseCase(billing);

      await checkout(
        const CheckoutRequest(
          clientRequestId: paymentRequestId,
          planId: basicPlanId,
          method: PaymentMethod.wallet,
          walletPhone: '٠١٠ ١٢٣٤ ٥٦٧٨',
        ),
      );
      await checkout(
        const CheckoutRequest(
          clientRequestId: paymentRequestId,
          planId: basicPlanId,
          method: PaymentMethod.card,
          walletPhone: '01012345678',
        ),
      );

      final sent = verify(() => billing.checkout(captureAny())).captured
          .cast<CheckoutRequest>();
      expect(sent.first.walletPhone, '01012345678');
      expect(sent.last.walletPhone, isNull);
      expect(sent.last.clientRequestId, paymentRequestId);
    });

    test('Delegates_PageSize20_FailuresPassedOn', () async {
      when(billing.getPlans).thenAnswer((_) async => Ok(billingPlans()));
      when(billing.getSubscription)
          .thenAnswer((_) async => Ok(subscriptionSummary()));
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => const Err(paymentNotFound));
      when(() => billing.cancelPayment(paymentId))
          .thenAnswer((_) async => const Err(notCancelable));
      when(
        () => billing.getPayments(
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          Paged(items: [payment()], page: 2, pageSize: 20, totalCount: 21),
        ),
      );

      expect(await GetPlansUseCase(billing).call(), isA<Ok<Object, Failure>>());
      expect(
        await GetSubscriptionUseCase(billing).call(),
        isA<Ok<Object, Failure>>(),
      );
      expect(
        (await GetPaymentUseCase(
          billing,
        ).call(paymentId) as Err<Payment, Failure>).failure,
        paymentNotFound,
      );
      expect(
        (await CancelPaymentUseCase(
          billing,
        ).call(paymentId) as Err<Payment, Failure>).failure,
        notCancelable,
      );
      await GetPaymentsUseCase(billing).call(page: 2);
      verify(
        () => billing.getPayments(page: 2, pageSize: PaymentPaging.pageSize),
      ).called(1);
    });
  });

  group('WatchPayment (polling B4 every 3 s)', () {
    final now = DateTime.utc(2026, 10, 12, 7);

    testWidgets('PollsEvery3s_StopsOnAFinalStatus', (tester) async {
      final answers = [
        payment(),
        payment(),
        payment(status: PaymentStatus.paid),
      ];
      var calls = 0;
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => Ok(answers[calls++]));
      final polls = <PaymentPoll>[];

      final subscription = WatchPaymentUseCase(billing)
          .call(paymentId, now: now)
          .listen(polls.add);
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      await tester.pump(PaymentPolling.interval);

      expect(calls, 3);
      expect(polls.whereType<PaymentPollPending>(), hasLength(2));
      expect(polls.last, PaymentPoll.finished(answers.last));
      await tester.pump(const Duration(seconds: 30));
      expect(calls, 3);
      unawaited(subscription.cancel());
    });

    testWidgets('Cancelled_NoMorePolls', (tester) async {
      var calls = 0;
      when(() => billing.getPayment(paymentId)).thenAnswer((_) async {
        calls++;
        return Ok(payment());
      });

      final subscription = WatchPaymentUseCase(billing)
          .call(paymentId, now: now)
          .listen((_) {});
      await tester.pump();
      unawaited(subscription.cancel());
      await tester.pump(const Duration(minutes: 1));

      expect(calls, 1);
    });

    testWidgets('PendingUntilExpiresAt_WindowEnded', (tester) async {
      var calls = 0;
      when(() => billing.getPayment(paymentId)).thenAnswer((_) async {
        calls++;
        return Ok(payment(expiresAt: now.add(const Duration(seconds: 9))));
      });
      final polls = <PaymentPoll>[];

      WatchPaymentUseCase(billing).call(paymentId, now: now).listen(polls.add);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));

      // The first poll and three more, the last at the expiry.
      expect(calls, 4);
      expect(polls.last, const PaymentPoll.windowEnded());
    });

    testWidgets('FailedPolls_KeepPolling', (tester) async {
      final answers = <Result<Payment, Failure>>[
        const Err(NetworkFailure()),
        Ok(payment(status: PaymentStatus.failed, failureReason: 'x')),
      ];
      var calls = 0;
      when(() => billing.getPayment(paymentId))
          .thenAnswer((_) async => answers[calls++]);
      final polls = <PaymentPoll>[];

      WatchPaymentUseCase(billing).call(paymentId, now: now).listen(polls.add);
      await tester.pump();
      await tester.pump(PaymentPolling.interval);

      expect(polls.first, const PaymentPoll.failed(NetworkFailure()));
      expect(polls.last, isA<PaymentPollFinished>());
    });
  });
}
