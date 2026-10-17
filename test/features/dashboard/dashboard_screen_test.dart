import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/hero_header.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';
import 'package:stockly/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:stockly/features/dashboard/presentation/widgets/summary_card.dart';
import 'package:stockly/features/dashboard/presentation/widgets/today_sales_card.dart';

import '../../helpers/auth_doubles.dart';
import '../../helpers/dashboard_doubles.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/routed_screen.dart';

/// Design §11 DashboardScreen: 4 states × ar/en, the card links, RTL and
/// dark.
void main() {
  late MockDashboardRepository repository;

  setUp(() => repository = MockDashboardRepository());

  void answer(Future<Result<DashboardSummary, Failure>> Function() result) =>
      when(repository.getSummary).thenAnswer((_) => result());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    bool disableAnimations = false,
  }) => pumpRoutedScreen(
    tester,
    const DashboardScreen(),
    themeMode: themeMode,
    disableAnimations: disableAnimations,
    overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
  );

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<DashboardSummary, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(routedL10n().navDashboard), findsOneWidget);
    pending.complete(Ok(summary()));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Empty_NewShop_AddProductOrScan', (tester) async {
    answer(() async => Ok(summary(productCount: 0)));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.text(l.dashboardEmptyTitle), findsOneWidget);
    expect(find.text(l.dashboardEmptyBody), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, l.invoicesScanAction),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, l.dashboardAddProduct));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.productCreate), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_RetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    answer(() async => Ok(summary()));
    await tester.tap(find.text(routedL10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(TodaySalesCard), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_CardsWithTheirCounts', (tester) async {
    answer(() async => Ok(summary()));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.byType(SummaryCard), findsNWidgets(5));
    for (final label in [
      l.dashboardLowStock,
      l.dashboardNegativeStock,
      l.dashboardExpiringSoon,
      l.dashboardAwaitingReview,
      l.dashboardProducts,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text(l.dashboardTodaySales), findsOneWidget);
    expect(find.text(l.dashboardSalesCount(3)), findsOneWidget);
    expect(find.text(l.dashboardOverriddenSales(1)), findsOneWidget);
    expect(find.textContaining('1,250.50'), findsOneWidget);
    expect(find.textContaining('31'), findsWidgets);
    final language = localeVariant.currentValue!.languageCode;
    expect(
      find.text(
        l.dashboardUpdatedAt(
          ltrIsolate(DateFormatter.time(summary().generatedAt, language)),
        ),
      ),
      findsOneWidget,
    );
  }, variant: localeVariant);

  testWidgets('Links_LowStockReviewSalesExpiringNewSale', (tester) async {
    answer(() async => Ok(summary()));
    final l = routedL10n();
    for (final (label, route, location) in [
      (l.dashboardLowStock, RouteNames.products, '/products?lowStock=true'),
      (
        l.dashboardNegativeStock,
        RouteNames.products,
        '/products?lowStock=true',
      ),
      (
        l.dashboardAwaitingReview,
        RouteNames.invoices,
        '/invoices?status=NeedsReview',
      ),
      (l.dashboardExpiringSoon, RouteNames.expiringSoon, '/expiring'),
      (l.dashboardTodaySales, RouteNames.sales, '/sales'),
      (l.dashboardProducts, RouteNames.products, '/products'),
      (l.salesNewSale, RouteNames.quickSale, '/quick-sale'),
    ]) {
      await pump(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(routedTo(route), findsOneWidget, reason: label);
      expect(find.text(location), findsOneWidget, reason: label);
    }
  }, variant: localeVariant);

  testWidgets('Rtl_CardsStartOnTheReadingSide', (tester) async {
    answer(() async => Ok(summary()));
    await pump(tester);
    await tester.pumpAndSettle();

    expectStartSide(tester, find.byIcon(Icons.point_of_sale_rounded));
    expectStartSide(tester, find.byIcon(Icons.trending_down_rounded));
  }, variant: localeVariant);

  testWidgets('Header_ShopNameOverTheCards', (tester) async {
    answer(() async => Ok(summary()));
    await pump(tester);
    await tester.pumpAndSettle();

    final shop = find.text(ownerSession.shop.name);
    expect(shop, findsOneWidget);
    expect(find.text(routedL10n().dashboardHeaderSubtitle), findsOneWidget);
    final header = tester.getRect(find.byType(HeroHeader));
    final card = tester.getRect(find.byType(TodaySalesCard));
    expect(card.top, lessThan(header.bottom), reason: 'the card overlaps');
    expect(card.bottom, greaterThan(header.bottom));
  }, variant: localeVariant);

  testWidgets('Counter_CountsUpToTheExactTotal', (tester) async {
    answer(() async => Ok(summary()));
    await pump(tester);
    await tester.pump();
    await tester.pump(StocklyDurations.standard.counter ~/ 4);

    expect(find.textContaining('1,250.50'), findsNothing);
    expect(find.textContaining('.'), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.textContaining('1,250.50'), findsOneWidget);
    expect(find.text(ltrIsolate('31')), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Stagger_OnlyOnFirstLoad_NotOnRefresh', (tester) async {
    answer(() async => Ok(summary()));
    await pump(tester);
    await tester.pump();

    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pumpAndSettle();

    ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)))
        .invalidate(dashboardSummaryProvider);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    verify(repository.getSummary).called(2);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    expect(find.byType(SummaryCard), findsNWidgets(5));
  }, variant: localeVariant);

  testWidgets('ReduceMotion_FinalFrameNoTicking', (tester) async {
    answer(() async => Ok(summary()));
    await pump(tester, disableAnimations: true);
    await tester.pump();

    expect(find.textContaining('1,250.50'), findsOneWidget);
    expect(find.text(ltrIsolate('31')), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    answer(() async => Ok(summary()));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(TodaySalesCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
