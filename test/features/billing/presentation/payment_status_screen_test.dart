import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/platform/external_browser.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/success_check.dart';
import 'package:stockly/features/billing/domain/entities/billing_timings.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/billing/presentation/screens/payment_status_screen.dart';
import 'package:stockly/features/billing/presentation/widgets/checkout_sheet.dart';
import 'package:stockly/features/billing/presentation/widgets/kiosk_reference_card.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/billing_doubles.dart';
import '../../../helpers/dashboard_doubles.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/routed_screen.dart';

/// Plans-payments brief PaymentStatusScreen: 4 states × ar/en, pending
/// card/wallet/kiosk, paid, failed, expired, polling until a final status,
/// cancel and "Try again" for the Owner only, dark and reduce motion.
void main() {
  late MockBillingRepository billing;
  late RecordingBrowser browser;

  setUpAll(registerBillingFallbacks);
  setUp(() {
    billing = quietBilling();
    browser = RecordingBrowser();
  });

  void answer(Future<Result<Payment, Failure>> Function() r) =>
      when(() => billing.getPayment(paymentId)).thenAnswer((_) => r());

  Future<void> pump(
    WidgetTester tester, {
    bool staff = false,
    ThemeMode themeMode = ThemeMode.light,
    bool disableAnimations = false,
  }) => pumpRoutedScreen(
    tester,
    const PaymentStatusScreen(paymentId: paymentId),
    session: staff ? staffSession : null,
    themeMode: themeMode,
    disableAnimations: disableAnimations,
    overrides: [
      billingRepositoryProvider.overrideWithValue(billing),
      externalBrowserProvider.overrideWithValue(browser),
      dashboardRepositoryProvider.overrideWithValue(quietDashboard()),
    ],
  );

  /// Unmounts the screen so its poll stops before the pending-timer check.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(PaymentPolling.interval);
  }

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<Payment, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(routedL10n().billingPaymentTitle), findsOneWidget);
    pending.complete(Ok(payment(status: PaymentStatus.paid)));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Error_NotFound_RetryLoads', (tester) async {
    answer(() async => const Err(paymentNotFound));
    await pump(tester);
    await tester.pump();
    await tester.pump();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(routedL10n().errorPaymentNotFound), findsOneWidget);
    answer(() async => Ok(payment(status: PaymentStatus.expired)));
    await tester.tap(find.text(routedL10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.text(routedL10n().billingExpiredTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('PendingCard_OpensThePage_PollsUntilPaid', (tester) async {
    final answers = [payment(), payment(status: PaymentStatus.paid)];
    var calls = 0;
    answer(() async => Ok(answers[calls++]));
    await pump(tester);
    await tester.pump();
    await tester.pump();

    final l = routedL10n();
    expect(find.text(l.billingWaitingTitle), findsOneWidget);
    expect(find.text(l.billingStatusPending), findsOneWidget);
    expect(find.textContaining('150.00'), findsOneWidget);
    await tester.tap(find.text(l.billingOpenPaymentPage));
    await tester.pump();
    expect(browser.opened, [Uri.parse(checkoutUrl)]);

    await tester.pump(PaymentPolling.interval);
    await tester.pumpAndSettle();
    expect(find.text(l.billingPaidTitle), findsOneWidget);
    expect(find.byType(SuccessCheck), findsOneWidget);
    expect(calls, 2);
    await tester.tap(find.text(l.billingDone));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.profile), findsOneWidget);
    expect(calls, 2);
  }, variant: localeVariant);

  testWidgets('OpenPaymentPage_NoBrowser_Snackbar', (tester) async {
    answer(() async => Ok(payment()));
    browser.opens = false;
    await pump(tester);
    await tester.pump();
    await tester.pump();

    final l = routedL10n();
    await tester.tap(find.text(l.billingOpenPaymentPage));
    await tester.pump();
    await tester.pump();

    expect(browser.opened, [Uri.parse(checkoutUrl)]);
    expect(find.text(l.billingPaymentPageNotOpened), findsOneWidget);
    await leave(tester);
  }, variant: localeVariant);

  testWidgets('PendingKiosk_ReferenceAndCopy', (tester) async {
    answer(() async => Ok(payment(method: PaymentMethod.kiosk)));
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);
    await tester.pump();
    await tester.pump();

    final l = routedL10n();
    expect(find.byType(KioskReferenceCard), findsOneWidget);
    expect(find.textContaining('700000001'), findsOneWidget);
    expect(find.text(l.billingOpenPaymentPage), findsNothing);
    await tester.tap(find.byTooltip(l.billingCopyReference));
    await tester.pump();
    expect(copied, ['700000001']);
    expect(find.text(l.billingReferenceCopied), findsOneWidget);
    await leave(tester);
  }, variant: localeVariant);

  testWidgets('Failed_ReasonAsSecondaryText_TryAgainOpensTheCheckout', (
    tester,
  ) async {
    answer(
      () async => Ok(
        payment(status: PaymentStatus.failed, failureReason: 'Do not honor'),
      ),
    );
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.text(l.billingFailedTitle), findsOneWidget);
    expect(find.text('Do not honor'), findsOneWidget);
    expect(find.text(l.billingCancelPayment), findsNothing);
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutSheet), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Failed_Staff_NoTryAgain', (tester) async {
    answer(() async => Ok(payment(status: PaymentStatus.failed)));
    await pump(tester, staff: true);
    await tester.pumpAndSettle();

    expect(find.text(routedL10n().billingFailedTitle), findsOneWidget);
    expect(find.text(routedL10n().commonRetry), findsNothing);
  }, variant: localeVariant);

  testWidgets('Pending_Staff_NoCancel', (tester) async {
    answer(() async => Ok(payment()));
    await pump(tester, staff: true);
    await tester.pump();
    await tester.pump();

    expect(find.text(routedL10n().billingWaitingTitle), findsOneWidget);
    expect(find.text(routedL10n().billingCancelPayment), findsNothing);
    await leave(tester);
  }, variant: localeVariant);

  testWidgets('Cancel_ConfirmedThenExpired', (tester) async {
    answer(() async => Ok(payment()));
    when(() => billing.cancelPayment(paymentId))
        .thenAnswer((_) async => Ok(payment(status: PaymentStatus.expired)));
    await pump(tester);
    await tester.pump();
    await tester.pump();

    final l = routedL10n();
    await tester.tap(find.text(l.billingCancelPayment));
    await tester.pumpAndSettle();
    expect(find.text(l.billingCancelConfirmTitle), findsOneWidget);
    await tester.tap(find.text(l.billingCancelPayment).last);
    await tester.pumpAndSettle();

    verify(() => billing.cancelPayment(paymentId)).called(1);
    expect(find.text(l.billingExpiredTitle), findsOneWidget);
    expect(find.text(l.billingStatusExpired), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Cancel_NotCancelable_Snackbar', (tester) async {
    answer(() async => Ok(payment()));
    when(() => billing.cancelPayment(paymentId))
        .thenAnswer((_) async => const Err(notCancelable));
    await pump(tester);
    await tester.pump();
    await tester.pump();

    final l = routedL10n();
    await tester.tap(find.text(l.billingCancelPayment));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.billingKeepPayment));
    await tester.pumpAndSettle();
    verifyNever(() => billing.cancelPayment(paymentId));
    await tester.tap(find.text(l.billingCancelPayment));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.billingCancelPayment).last);
    await tester.pump();
    await tester.pump();

    expect(find.text(l.errorBillingNotCancelable), findsOneWidget);
    await leave(tester);
  }, variant: localeVariant);

  testWidgets('StillPendingAtExpiry_RefreshAsksAgain', (tester) async {
    var calls = 0;
    answer(() async {
      calls++;
      return Ok(payment(expiresAt: DateTime.utc(2026, 10, 12, 7)));
    });
    await pump(tester);
    await tester.pump();
    await tester.pump();

    final l = routedL10n();
    expect(find.text(l.billingStillWaiting), findsOneWidget);
    await tester.tap(find.text(l.billingRefresh));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
  }, variant: localeVariant);

  testWidgets('Paid_DoneGoesToTheProfile', (tester) async {
    answer(() async => Ok(payment(status: PaymentStatus.paid)));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(routedL10n().billingPaidBody('الأساسية')), findsOneWidget);
    await tester.tap(find.text(routedL10n().billingDone));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.profile), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    answer(() async => Ok(payment(method: PaymentMethod.kiosk)));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pump();
    await tester.pump();

    expect(find.byType(KioskReferenceCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await leave(tester);
  }, variant: localeVariant);

  testWidgets('ReduceMotion_SuccessCheckFinalFrame', (tester) async {
    answer(() async => Ok(payment(status: PaymentStatus.paid)));
    await pump(tester, disableAnimations: true);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SuccessCheck), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  }, variant: localeVariant);
}
