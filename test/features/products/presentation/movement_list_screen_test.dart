import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';
import 'package:stockly/features/products/presentation/screens/movement_list_screen.dart';
import 'package:stockly/features/products/presentation/widgets/movement_list_tile.dart';

import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'screen_harness.dart';

/// Design §11 `MovementListScreen`: 4 states × ar/en, reason labels,
/// signed change, balance, note, links, dark.
void main() {
  late MockProductsRepository repository;

  setUpAll(registerProductFallbacks);
  setUp(() {
    repository = MockProductsRepository();
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => Ok(detail()));
  });

  void stub(
    FutureOr<Result<Paged<StockMovement>, Failure>> Function() answer,
  ) => when(
    () => repository.getMovements(
      productId,
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((_) async => await answer());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpProductScreen(
      tester,
      const MovementListScreen(productId: productId),
      repository: repository,
      themeMode: themeMode,
    );
    await tester.pump();
  }

  final movements = [
    movement(id: 'm3'),
    movement(
      id: 'm2',
      change: '18.000',
      balance: '24.000',
      reason: StockMovementReason.invoiceReceipt,
      note: null,
      invoiceId: '0192f0a0-6c1e-7b3a-9d2e-d00000000001',
    ),
    movement(
      id: 'm1',
      change: '6.000',
      balance: '6.000',
      reason: StockMovementReason.stockCount,
      note: 'Opening stock',
    ),
  ];

  testWidgets('Loading_FirstPage', (tester) async {
    final pending = Completer<Result<Paged<StockMovement>, Failure>>();
    when(
      () => repository.getMovements(
        productId,
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => pending.future);

    await pumpProductScreen(
      tester,
      const MovementListScreen(productId: productId),
      repository: repository,
    );

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().movementsTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_NoMovementsYet', (tester) async {
    stub(() => Ok(page<StockMovement>(const [])));

    await pump(tester);

    expect(find.text(l10n().movementsEmptyTitle), findsOneWidget);
    expect(find.text(l10n().movementsEmptyBody), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_NotFound_BackAndRetry', (tester) async {
    stub(() => const Err(productNotFound));

    await pump(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorProductNotFound), findsOneWidget);
    expect(find.text(l10n().commonRetry), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_ReasonSignedChangeBalanceNoteAndLink', (tester) async {
    stub(() => Ok(page(movements)));

    await pump(tester);

    final l = l10n();
    expect(find.byType(MovementListTile), findsNWidgets(3));
    for (final text in [
      l.movementReasonManualAdjustment,
      l.movementReasonInvoiceReceipt,
      l.movementReasonStockCount,
      '\u2066-2\u2069',
      '\u2066+18\u2069',
      l.movementsBalanceAfter(l.quantityWithUnit('\u206622\u2069', 'شريط')),
      'Expired, thrown away',
      'Opening stock',
      l.movementsOpenInvoice,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.text(l.movementsOpenSale), findsNothing);
  }, variant: localeVariant);

  testWidgets('Dark_DataRenders', (tester) async {
    stub(() => Ok(page(movements)));

    await pump(tester, themeMode: ThemeMode.dark);

    expect(
      Theme.of(tester.element(find.byType(MovementListTile).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
