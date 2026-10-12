import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/presentation/screens/stock_count_screen.dart';
import 'package:stockly/features/products/presentation/widgets/unit_picker.dart';

import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'screen_harness.dart';

/// Design §11 `StockCountScreen`: 4 states × ar/en, "Count matches,
/// nothing changed", the new quantity, dark.
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
      const StockCountScreen(productId: productId),
      repository: repository,
      themeMode: themeMode,
    );
    await tester.pump();
  }

  Future<void> count(WidgetTester tester, String value) async {
    await enterField(tester, l10n().stockCountQuantity, value);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
  }

  testWidgets('Loading_ProductPreload', (tester) async {
    final pending = Completer<Result<ProductDetail, Failure>>();
    when(() => repository.getProduct(productId))
        .thenAnswer((_) => pending.future);

    await pumpProductScreen(
      tester,
      const StockCountScreen(productId: productId),
      repository: repository,
    );

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().stockCountTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_BlankForm', (tester) async {
    await pump(tester);

    final l = l10n();
    expect(find.text(l.stockCountQuantity), findsOneWidget);
    expect(fieldError(tester, l.stockCountQuantity), isNull);
    expect(find.byType(UnitPicker), findsOneWidget);
    expect(find.text(l.stockCountUnchanged), findsNothing);
  }, variant: localeVariant);

  testWidgets('Error_TooManyDecimalsLocally_AndServerBanner', (tester) async {
    when(() => repository.recordStockCount(productId, any())).thenAnswer(
      (_) async => Err(invalidInput(ApiErrorCode.precisionOutOfRange)),
    );
    await pump(tester);
    final l = l10n();

    await count(tester, '1.2345');
    expect(
      fieldError(tester, l.stockCountQuantity),
      l.errorPrecisionTooManyDecimals,
    );

    await count(tester, '1');
    expect(find.byType(FormBanner), findsOneWidget);
    expect(find.text(l.errorPrecisionOutOfRange), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_PreloadNotFound', (tester) async {
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => const Err(productNotFound));

    await pump(tester);

    expect(find.byType(ErrorState), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_CountMatches_NothingChanged', (tester) async {
    when(
      () => repository.recordStockCount(productId, any()),
    ).thenAnswer((_) async => Ok(countResult(changed: false, qty: '24.000')));
    await pump(tester);

    await count(tester, '24');

    expect(find.text(l10n().stockCountUnchanged), findsOneWidget);
    final draft =
        verify(() => repository.recordStockCount(productId, captureAny()))
                .captured
                .single
            as StockCountDraft;
    expect(draft.countedQuantity.toApi(), '24.000');
    expect(draft.unitId, isNull);
  }, variant: localeVariant);

  testWidgets('Data_CountDiffers_NewQuantity', (tester) async {
    when(() => repository.recordStockCount(productId, any()))
        .thenAnswer((_) async => Ok(countResult(changed: true)));
    await pump(tester);

    await count(tester, '26');
    await tester.pump();

    final l = l10n();
    expect(
      find.text(
        l.stockCountChanged(l.quantityWithUnit('\u206626\u2069', 'شريط')),
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
