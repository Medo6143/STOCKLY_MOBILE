import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/billing/presentation/screens/payment_history_screen.dart';
import 'package:stockly/features/billing/presentation/widgets/payment_tile.dart';

import '../../../helpers/billing_doubles.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/routed_screen.dart';

/// Plans-payments brief PaymentHistoryScreen: 4 states × ar/en, status
/// pills, the link to a payment, dark.
void main() {
  late MockBillingRepository billing;

  setUp(() => billing = quietBilling());

  void answer(Future<Result<Paged<Payment>, Failure>> Function() r) => when(
    () => billing.getPayments(
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((_) => r());

  Paged<Payment> pageOf(List<Payment> items) =>
      Paged(items: items, page: 1, pageSize: 20, totalCount: items.length);

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpRoutedScreen(
    tester,
    const PaymentHistoryScreen(),
    themeMode: themeMode,
    overrides: [billingRepositoryProvider.overrideWithValue(billing)],
  );

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<Paged<Payment>, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(routedL10n().billingPaymentHistory), findsOneWidget);
    pending.complete(Ok(pageOf(const [])));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Empty_SeePlans', (tester) async {
    answer(() async => Ok(pageOf(const [])));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.text(l.billingHistoryEmptyTitle), findsOneWidget);
    await tester.tap(find.text(l.billingSeePlans));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.plans), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_RetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    answer(() async => Ok(pageOf([payment()])));
    await tester.tap(find.text(routedL10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentTile), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_StatusPillsAndLink', (tester) async {
    answer(
      () async => Ok(
        pageOf([
          payment(),
          payment(id: proPlanId, status: PaymentStatus.paid),
          payment(
            id: freePlanId,
            method: PaymentMethod.kiosk,
            status: PaymentStatus.expired,
          ),
        ]),
      ),
    );
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.byType(PaymentTile), findsNWidgets(3));
    for (final text in [
      l.billingStatusPending,
      l.billingStatusPaid,
      l.billingStatusExpired,
    ]) {
      expect(
        find.widgetWithText(StatusPill, text),
        findsOneWidget,
        reason: text,
      );
    }
    expectStartSide(tester, find.byIcon(Icons.storefront_rounded));
    await tester.tap(find.byType(PaymentTile).first);
    await tester.pumpAndSettle();
    expect(find.text('/payment/$paymentId'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    answer(() async => Ok(pageOf([payment()])));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(PaymentTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
