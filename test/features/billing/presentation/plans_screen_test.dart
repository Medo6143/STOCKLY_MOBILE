import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/platform/external_browser.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/success_check.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/billing/presentation/screens/plans_screen.dart';
import 'package:stockly/features/billing/presentation/widgets/checkout_sheet.dart';
import 'package:stockly/features/billing/presentation/widgets/payment_method_option.dart';
import 'package:stockly/features/billing/presentation/widgets/plan_option_card.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/billing_doubles.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/routed_screen.dart';

/// Plans-payments brief PlansScreen and CheckoutSheet: 4 states × ar/en,
/// Owner vs Staff, the checkout per method, wallet phone rules, errors in
/// the banner, dark, RTL and reduce motion.
void main() {
  late MockBillingRepository billing;
  late RecordingBrowser browser;

  setUpAll(registerBillingFallbacks);
  setUp(() {
    billing = quietBilling();
    browser = RecordingBrowser();
  });

  void answer(Future<Result<List<BillingPlan>, Failure>> Function() r) =>
      when(billing.getPlans).thenAnswer((_) => r());

  Future<void> pump(
    WidgetTester tester, {
    bool staff = false,
    ThemeMode themeMode = ThemeMode.light,
    bool disableAnimations = false,
  }) => pumpRoutedScreen(
    tester,
    const PlansScreen(),
    session: staff ? staffSession : null,
    themeMode: themeMode,
    disableAnimations: disableAnimations,
    overrides: [
      billingRepositoryProvider.overrideWithValue(billing),
      externalBrowserProvider.overrideWithValue(browser),
    ],
  );

  Finder choose() =>
      find.widgetWithText(FilledButton, routedL10n().billingChoose);

  Future<void> openCheckout(WidgetTester tester) async {
    await tester.tap(choose().first);
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutSheet), findsOneWidget);
  }

  Future<void> pay(WidgetTester tester) async {
    await tester.tap(find.text(routedL10n().billingPay));
    await tester.pumpAndSettle();
  }

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<List<BillingPlan>, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(routedL10n().billingPlansTitle), findsOneWidget);
    pending.complete(Ok(billingPlans()));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Empty', (tester) async {
    answer(() async => const Ok([]));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(routedL10n().billingPlansEmptyTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_RetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    answer(() async => Ok(billingPlans()));
    await tester.tap(find.text(routedL10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(PlanOptionCard), findsNWidgets(3));
  }, variant: localeVariant);

  testWidgets('Data_Owner_ChooseOnPaidNotCurrent_CurrentMarked', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.byType(PlanOptionCard), findsNWidgets(3));
    expect(find.text(l.billingCurrentPlan), findsOneWidget);
    expect(find.text(l.billingFree), findsOneWidget);
    expect(find.textContaining('150.00'), findsOneWidget);
    expect(find.text(l.billingPlanQuota(500)), findsOneWidget);
    expect(find.text(l.billingPlanMembers(10)), findsOneWidget);
    expect(choose(), findsNWidgets(2));
    expect(find.text(l.billingStaffNote), findsNothing);
    expectStartSide(tester, find.text('المجانية'));
  }, variant: localeVariant);

  testWidgets('Data_Staff_ReadOnlyWithANote', (tester) async {
    await pump(tester, staff: true);
    await tester.pumpAndSettle();

    expect(find.byType(PlanOptionCard), findsNWidgets(3));
    expect(choose(), findsNothing);
    expect(find.text(routedL10n().billingStaffNote), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('History_OpensFromTheAppBar', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_rounded));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.paymentHistory), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Checkout_Card_OpensThePageAndTheStatus', (tester) async {
    when(() => billing.checkout(any())).thenAnswer((_) async => Ok(payment()));
    await pump(tester);
    await tester.pumpAndSettle();

    await openCheckout(tester);
    final l = routedL10n();
    expect(find.byType(PaymentMethodOption), findsNWidgets(3));
    for (final text in [
      l.billingMethodCardHint,
      l.billingMethodWalletHint,
      l.billingMethodKioskHint,
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.text(l.billingCheckoutTitle('الأساسية')), findsOneWidget);
    expect(find.textContaining('150.00'), findsWidgets);
    expect(find.text(l.billingWalletPhone), findsNothing);
    await pay(tester);

    expect(browser.opened, [Uri.parse(checkoutUrl)]);
    expect(routedTo(RouteNames.paymentStatus), findsOneWidget);
    expect(find.text('/payment/$paymentId'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Checkout_Wallet_PhoneRules', (tester) async {
    when(() => billing.checkout(any()))
        .thenAnswer((_) async => Ok(payment(method: PaymentMethod.wallet)));
    await pump(tester);
    await tester.pumpAndSettle();
    await openCheckout(tester);
    final l = routedL10n();

    await tester.tap(find.text(l.billingMethodWallet));
    await tester.pumpAndSettle();
    expect(find.text(l.billingWalletPhone), findsOneWidget);
    await pay(tester);
    expect(find.text(l.billingWalletPhoneRequired), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0131234567');
    await pay(tester);
    expect(find.text(l.billingWalletPhoneInvalid), findsOneWidget);
    verifyNever(() => billing.checkout(any()));

    await tester.enterText(find.byType(TextField), '٠١٠١٢٣٤٥٦٧٨');
    await pay(tester);
    expect(routedTo(RouteNames.paymentStatus), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Checkout_Kiosk_NoBrowser', (tester) async {
    when(() => billing.checkout(any()))
        .thenAnswer((_) async => Ok(payment(method: PaymentMethod.kiosk)));
    await pump(tester);
    await tester.pumpAndSettle();
    await openCheckout(tester);

    await tester.tap(find.text(routedL10n().billingMethodKiosk));
    await tester.pumpAndSettle();
    await pay(tester);

    expect(browser.opened, isEmpty);
    expect(routedTo(RouteNames.paymentStatus), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Checkout_MethodUnavailable_InTheBanner', (tester) async {
    when(() => billing.checkout(any()))
        .thenAnswer((_) async => const Err(methodUnavailable));
    await pump(tester);
    await tester.pumpAndSettle();
    await openCheckout(tester);
    await pay(tester);

    expect(find.byType(FormBanner), findsOneWidget);
    expect(
      find.text(routedL10n().errorBillingMethodUnavailable),
      findsOneWidget,
    );
    expect(find.byType(CheckoutSheet), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Checkout_PaymentPending_OpensThePendingPayment', (tester) async {
    when(() => billing.checkout(any()))
        .thenAnswer((_) async => const Err(paymentPending));
    when(billing.getSubscription).thenAnswer(
      (_) async => Ok(subscriptionSummary(pendingPayment: payment())),
    );
    await pump(tester);
    await tester.pumpAndSettle();
    await openCheckout(tester);
    await pay(tester);

    final l = routedL10n();
    expect(find.text(l.errorBillingPaymentPending), findsOneWidget);
    await tester.tap(find.text(l.billingOpenPendingPayment));
    await tester.pumpAndSettle();
    expect(find.text('/payment/$paymentId'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(PlanOptionCard), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);

  testWidgets('ReduceMotion_SettlesAtOnce', (tester) async {
    await pump(tester, disableAnimations: true);
    await tester.pump();
    await tester.pump();

    expect(find.byType(PlanOptionCard), findsNWidgets(3));
    expect(find.byType(SuccessCheck), findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  }, variant: localeVariant);
}
