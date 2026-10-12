import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/presentation/screens/stock_adjustment_screen.dart';
import 'package:stockly/features/products/presentation/widgets/unit_picker.dart';

import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'screen_harness.dart';

/// Design §11 `StockAdjustmentScreen`: 4 states × ar/en, unit picker,
/// result, dark.
void main() {
  late MockProductsRepository repository;

  setUpAll(registerProductFallbacks);
  setUp(() {
    repository = MockProductsRepository();
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => Ok(detail()));
  });

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpProductScreen(
      tester,
      const StockAdjustmentScreen(productId: productId),
      repository: repository,
      themeMode: themeMode,
    );
    await tester.pump();
  }

  Finder submit() => find.byType(FilledButton);

  testWidgets('Loading_ProductPreload', (tester) async {
    final pending = Completer<Result<ProductDetail, Failure>>();
    when(() => repository.getProduct(productId))
        .thenAnswer((_) => pending.future);

    await pumpProductScreen(
      tester,
      const StockAdjustmentScreen(productId: productId),
      repository: repository,
    );

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().stockAdjustTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_BlankFormWithCurrentStock', (tester) async {
    await pump(tester);

    final l = l10n();
    expect(find.text(l.stockCurrentQuantity), findsOneWidget);
    expect(
      find.text(l.quantityWithUnit('\u206624\u2069', 'شريط')),
      findsOneWidget,
    );
    expect(find.byType(UnitPicker), findsOneWidget);
    expect(fieldError(tester, l.stockAdjustChange), isNull);
    expect(fieldError(tester, l.stockAdjustNote), isNull);
  }, variant: localeVariant);

  testWidgets('Error_PreloadFailed_Retry', (tester) async {
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => const Err(productNotFound));

    await pump(tester);

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorProductNotFound), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_ZeroAndMissingReason_UnderTheirFields', (tester) async {
    await pump(tester);
    final l = l10n();
    await enterField(tester, l.stockAdjustChange, '0');

    await tester.tap(submit());
    await tester.pump();

    expect(fieldError(tester, l.stockAdjustChange), l.errorStockZeroChange);
    expect(fieldError(tester, l.stockAdjustNote), l.productsFieldRequired);
    verifyNever(() => repository.adjustStock(any(), any()));
  }, variant: localeVariant);

  testWidgets('Error_Forbidden_InTheBanner', (tester) async {
    when(() => repository.adjustStock(productId, any()))
        .thenAnswer((_) async => const Err(forbidden));
    await pump(tester);
    final l = l10n();
    await enterField(tester, l.stockAdjustChange, '-2');
    await enterField(tester, l.stockAdjustNote, 'تالف');

    await tester.tap(submit());
    await tester.pump();

    expect(find.byType(FormBanner), findsOneWidget);
    expect(find.text(l.errorAuthForbidden), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_SubmitInABox_ShowsTheNewBalance', (tester) async {
    final pending = Completer<Result<StockMovement, Failure>>();
    when(() => repository.adjustStock(productId, any()))
        .thenAnswer((_) => pending.future);
    await pump(tester);
    final l = l10n();
    await tester.tap(find.byType(UnitPicker));
    await tester.pumpAndSettle();
    await tester.tap(find.text('علبة').last);
    await tester.pumpAndSettle();
    await enterField(tester, l.stockAdjustChange, '-١');
    await enterField(tester, l.stockAdjustNote, 'Expired');

    await tester.tap(submit());
    await tester.pump();
    expect(
      find.descendant(
        of: submit(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    pending.complete(Ok(movement(change: '-3.000', balance: '21.000')));
    await tester.pump();

    final draft =
        verify(() => repository.adjustStock(productId, captureAny()))
                .captured
                .single
            as StockAdjustmentDraft;
    expect(draft.unitId, boxUnitId);
    expect(draft.quantityChange.toApi(), '-1.000');
    expect(
      find.text(
        l.stockAdjustDone(l.quantityWithUnit('\u206621\u2069', 'شريط')),
      ),
      findsOneWidget,
    );
  }, variant: localeVariant);

  testWidgets('Dark_FormRenders', (tester) async {
    await pump(tester, themeMode: ThemeMode.dark);

    expect(
      Theme.of(tester.element(find.byType(UnitPicker))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
