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
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';
import 'package:stockly/features/sales/presentation/screens/sale_list_screen.dart';
import 'package:stockly/features/sales/presentation/widgets/sale_list_tile.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/routed_screen.dart';
import '../../../helpers/sales_doubles.dart';

/// Design §11 SaleListScreen: 4 states × ar/en, the period filter, the
/// links and dark.
void main() {
  late MockSalesRepository sales;

  setUpAll(registerSaleFallbacks);
  setUp(() => sales = MockSalesRepository());

  void answer(Future<Result<Paged<SaleListItem>, Failure>> Function() r) =>
      when(
        () => sales.getSales(
          from: any(named: 'from'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => r());

  Paged<SaleListItem> pageOf(List<SaleListItem> items) =>
      Paged(items: items, page: 1, pageSize: 20, totalCount: items.length);

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpRoutedScreen(
    tester,
    const SaleListScreen(),
    themeMode: themeMode,
    overrides: [salesRepositoryProvider.overrideWithValue(sales)],
  );

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<Paged<SaleListItem>, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(routedL10n().navSales), findsOneWidget);
    pending.complete(Ok(pageOf(const [])));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Empty_NewSaleOpensTheQuickSale', (tester) async {
    answer(() async => Ok(pageOf(const [])));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.text(l.salesListEmptyTitle), findsOneWidget);
    expect(find.text(l.salesListEmptyBody), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l.salesNewSale));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.quickSale), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_RetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    answer(() async => Ok(pageOf([saleListItem()])));
    await tester.tap(find.text(routedL10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(SaleListTile), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_RowsAndDetailLink', (tester) async {
    answer(() async => Ok(pageOf([saleListItem()])));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(routedL10n().salesItemCount(2)), findsOneWidget);
    expect(find.textContaining('30.00'), findsOneWidget);
    expectStartSide(tester, find.byIcon(Icons.receipt_rounded));

    await tester.tap(find.byType(SaleListTile));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.saleDetail), findsOneWidget);
    expect(find.text('/sale/$saleId'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Filter_TodaySevenDaysAll', (tester) async {
    answer(() async => Ok(pageOf([saleListItem()])));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text(routedL10n().salesRangeAll));
    await tester.pumpAndSettle();

    final froms = verify(
      () => sales.getSales(
        from: captureAny(named: 'from'),
        page: 1,
        pageSize: any(named: 'pageSize'),
      ),
    ).captured;
    expect(froms, hasLength(2));
    expect(froms.first, isA<DateTime>());
    expect(froms.last, isNull);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    answer(() async => Ok(pageOf([saleListItem()])));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(SaleListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
