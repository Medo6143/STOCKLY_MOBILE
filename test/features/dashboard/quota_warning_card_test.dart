import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:stockly/features/dashboard/presentation/widgets/quota_warning_card.dart';

import '../../helpers/auth_doubles.dart';
import '../../helpers/billing_doubles.dart';
import '../../helpers/dashboard_doubles.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/routed_screen.dart';

/// Plans-payments brief: the dashboard's 80 % quota warning, Owner only,
/// with "Upgrade" to the plans.
void main() {
  late MockBillingRepository billing;

  setUp(() => billing = quietBilling());

  Future<void> pump(
    WidgetTester tester, {
    int scansToday = 40,
    bool staff = false,
    bool fails = false,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    when(billing.getSubscription).thenAnswer(
      (_) async => fails
          ? const Err(NetworkFailure())
          : Ok(subscriptionSummary(scansToday: scansToday)),
    );
    return pumpRoutedScreen(
      tester,
      const DashboardScreen(),
      session: staff ? staffSession : null,
      themeMode: themeMode,
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(quietDashboard()),
        billingRepositoryProvider.overrideWithValue(billing),
      ],
    );
  }

  Finder warning() => find.text(routedL10n().billingQuotaWarningTitle);

  testWidgets('Owner_At80Percent_UpgradeOpensThePlans', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(warning(), findsOneWidget);
    expect(find.text(routedL10n().billingScansToday(40, 50)), findsOneWidget);
    await tester.tap(find.text(routedL10n().billingUpgrade));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.plans), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Below80Percent_Hidden', (tester) async {
    await pump(tester, scansToday: 39);
    await tester.pumpAndSettle();

    expect(find.byType(QuotaWarningCard), findsOneWidget);
    expect(warning(), findsNothing);
  }, variant: localeVariant);

  testWidgets('Staff_NeverShown', (tester) async {
    await pump(tester, scansToday: 50, staff: true);
    await tester.pumpAndSettle();

    expect(find.byType(QuotaWarningCard), findsNothing);
    verifyNever(billing.getSubscription);
  }, variant: localeVariant);

  testWidgets('PlanFailedToLoad_DashboardUnaffected', (tester) async {
    await pump(tester, fails: true);
    await tester.pumpAndSettle();

    expect(warning(), findsNothing);
    expect(find.text(routedL10n().dashboardTodaySales), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(warning(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
