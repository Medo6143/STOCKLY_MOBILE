import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';
import 'package:stockly/features/sales/presentation/screens/sale_detail_screen.dart';
import 'package:stockly/features/sales/presentation/widgets/negative_stock_warning.dart';
import 'package:stockly/features/sales/presentation/widgets/sale_item_tile.dart';

import '../../../helpers/pump_app.dart';
import '../../../helpers/routed_screen.dart';
import '../../../helpers/sales_doubles.dart';

/// Design §11 SaleDetailScreen: loading, not-found error (the empty state
/// does not apply: a sale has lines), data with override marker and
/// negative-stock warnings, the "already recorded" line, RTL and dark.
void main() {
  late MockSalesRepository sales;

  setUp(() => sales = MockSalesRepository());

  void answer(Future<Result<Sale, Failure>> Function() result) =>
      when(() => sales.getSale(saleId)).thenAnswer((_) => result());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    bool alreadyRecorded = false,
  }) => pumpRoutedScreen(
    tester,
    SaleDetailScreen(saleId: saleId, alreadyRecorded: alreadyRecorded),
    themeMode: themeMode,
    overrides: [salesRepositoryProvider.overrideWithValue(sales)],
  );

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<Sale, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(routedL10n().salesDetailTitle), findsOneWidget);
    pending.complete(Ok(sale()));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Error_NotFoundWithBack', (tester) async {
    answer(() async => const Err(saleNotFound));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l.errorSaleNotFound), findsOneWidget);
    expect(find.text(l.commonBack), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_NetworkRetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    answer(() async => Ok(sale()));
    await tester.tap(find.text(routedL10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(SaleItemTile), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_LinesTotalNoteAndOverride', (tester) async {
    answer(() async => Ok(sale(items: [saleItem(price: '14.00')])));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.byType(SaleItemTile), findsOneWidget);
    expect(find.text('بنادول اكسترا'), findsOneWidget);
    expect(find.text(l.salesPriceOverridden), findsOneWidget);
    expect(find.text(l.salesHasOverride), findsOneWidget);
    expect(find.text(l.salesNoteValue('دفع كاش')), findsOneWidget);
    expect(find.text(l.salesTotalLabel), findsOneWidget);
    expect(find.byType(NegativeStockWarning), findsNothing);
    expect(find.text(l.salesAlreadyRecorded), findsNothing);
  }, variant: localeVariant);

  testWidgets('Data_NegativeStockWarningAndAlreadyRecorded', (tester) async {
    answer(() async => Ok(sale(negative: true, note: null)));
    await pump(tester, alreadyRecorded: true);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.byType(NegativeStockWarning), findsOneWidget);
    expect(
      find.text(l.salesNegativeStockWarning('بنادول اكسترا')),
      findsOneWidget,
    );
    expect(find.text(l.salesAlreadyRecorded), findsOneWidget);
    expectStartSide(tester, find.byIcon(Icons.warning_amber_rounded));
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    answer(() async => Ok(sale(negative: true)));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(SaleItemTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
