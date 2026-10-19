import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/settings/presentation/widgets/your_plan_card.dart';

import '../../helpers/billing_doubles.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/routed_screen.dart';

/// Plans-payments brief "Your plan" on the profile: 4 states × ar/en,
/// quota and members, renewal date, the pending banner, links, dark.
void main() {
  late MockBillingRepository billing;

  setUp(() => billing = quietBilling());

  void answer(Future<Result<SubscriptionSummary, Failure>> Function() r) =>
      when(billing.getSubscription).thenAnswer((_) => r());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpRoutedScreen(
    tester,
    const Scaffold(body: SingleChildScrollView(child: YourPlanCard())),
    themeMode: themeMode,
    overrides: [billingRepositoryProvider.overrideWithValue(billing)],
  );

  testWidgets('Loading_Skeleton', (tester) async {
    final pending = Completer<Result<SubscriptionSummary, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.bySemanticsLabel(routedL10n().commonLoading), findsOneWidget);
    pending.complete(Ok(subscriptionSummary()));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Error_RetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.text(l.billingPlanError), findsOneWidget);
    answer(() async => Ok(subscriptionSummary()));
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();
    expect(find.text(l.billingYourPlan), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_FreePlan_QuotaMembers_OpensThePlans', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.text('المجانية'), findsOneWidget);
    expect(find.text(l.billingFree), findsOneWidget);
    expect(find.text(l.billingScansToday(12, 50)), findsOneWidget);
    expect(find.text(l.billingMembers(2, 2)), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(12 / 50, 1e-9));
    expect(find.textContaining(l.billingRenewsOn('')), findsNothing);
    expect(find.text(l.billingPendingBanner), findsNothing);
    await tester.tap(find.text(l.billingYourPlan));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.plans), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_PaidPlanRenewal_PendingBannerOpensThePayment', (
    tester,
  ) async {
    const endsOn = CalendarDate(2026, 11, 12);
    answer(
      () async => Ok(
        subscriptionSummary(
          plan: billingPlan(isCurrent: true),
          quota: 150,
          endsOn: endsOn,
          pendingPayment: payment(),
        ),
      ),
    );
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    final language = routedIsArabic ? 'ar' : 'en';
    expect(find.textContaining('150.00'), findsOneWidget);
    expect(
      find.text(
        l.billingRenewsOn(ltrIsolate(DateFormatter.date(endsOn, language))),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(l.billingPendingBanner));
    await tester.pumpAndSettle();
    expect(find.text('/payment/$paymentId'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    answer(
      () async =>
          Ok(subscriptionSummary(scansToday: 45, pendingPayment: payment())),
    );
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.text(routedL10n().billingYourPlan), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
