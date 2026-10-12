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
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/products/presentation/screens/unit_form_screen.dart';

import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'screen_harness.dart';

/// Design §11 `UnitFormScreen` (add, edit, delete): 4 states × ar/en, base
/// unit rules, dark.
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
    String? unitId,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpProductScreen(
      tester,
      UnitFormScreen(productId: productId, unitId: unitId),
      repository: repository,
      themeMode: themeMode,
    );
    await tester.pump();
  }

  String factorLabel() => l10n().unitsFormFactor('شريط');

  testWidgets('Loading_ProductPreload', (tester) async {
    final pending = Completer<Result<ProductDetail, Failure>>();
    when(() => repository.getProduct(productId))
        .thenAnswer((_) => pending.future);

    await pumpProductScreen(
      tester,
      const UnitFormScreen(productId: productId),
      repository: repository,
    );

    expect(find.byType(LoadingState), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_AddIsTheBlankForm_NoDelete', (tester) async {
    await pump(tester);

    final l = l10n();
    expect(find.text(l.unitsFormCreateTitle), findsOneWidget);
    for (final label in [
      l.unitsFormName,
      factorLabel(),
      l.unitsFormSellPrice,
      l.productsFormBarcode,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(fieldError(tester, label), isNull);
    }
    expect(find.text(l.unitsDelete), findsNothing);
  }, variant: localeVariant);

  testWidgets('Empty_ArchivedProduct_UnitsCannotChange', (tester) async {
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => Ok(detail(isArchived: true)));

    await pump(tester);

    expect(find.text(l10n().unitsArchivedTitle), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  }, variant: localeVariant);

  testWidgets('Error_UnknownUnit_NotFound', (tester) async {
    await pump(tester, unitId: '0192f0a0-6c1e-7b3a-9d2e-ffffffffffff');

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorProductUnitNotFound), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_DuplicateNameUnderName_InUseInBanner', (tester) async {
    when(() => repository.addUnit(productId, any())).thenAnswer(
      (_) async => Err(conflict(ApiErrorCode.productUnitDuplicateName)),
    );
    await pump(tester);
    final l = l10n();
    await enterField(tester, l.unitsFormName, 'علبة');
    await enterField(tester, factorLabel(), '3');
    await enterField(tester, l.unitsFormSellPrice, '40');

    await tester.tap(find.text(l.unitsFormSubmit));
    await tester.pump();

    expect(
      fieldError(tester, l.unitsFormName),
      l.errorProductUnitDuplicateName,
    );
  }, variant: localeVariant);

  testWidgets('Error_LocalFactorIssue', (tester) async {
    await pump(tester);
    final l = l10n();
    await enterField(tester, l.unitsFormName, 'علبة');
    await enterField(tester, factorLabel(), '0');
    await enterField(tester, l.unitsFormSellPrice, '40');

    await tester.tap(find.text(l.unitsFormSubmit));
    await tester.pump();

    expect(fieldError(tester, factorLabel()), l.errorPrecisionNotPositive);
    verifyNever(() => repository.addUnit(any(), any()));
  }, variant: localeVariant);

  testWidgets('Data_EditFilled_SaveSendsP7', (tester) async {
    when(() => repository.updateUnit(productId, boxUnitId, any()))
        .thenAnswer((_) async => Ok(boxUnit));
    await pump(tester, unitId: boxUnitId);

    final l = l10n();
    expect(find.text(l.unitsFormEditTitle), findsOneWidget);
    expect(find.text('علبة'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('40.00'), findsOneWidget);
    expect(find.text('6221234567906'), findsOneWidget);
    expect(find.text(l.unitsDelete), findsOneWidget);
    await enterField(tester, l.unitsFormSellPrice, '42.5');
    await tester.tap(find.text(l.unitsFormSubmit));
    await tester.pump();

    final draft =
        verify(() => repository.updateUnit(productId, boxUnitId, captureAny()))
                .captured
                .single
            as UnitDraft;
    expect(draft.sellPrice.toApi(), '42.50');
    expect(draft.factor.toApi(), '3.000000');
    expect(find.text(l.unitsSaved), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_BaseUnit_FactorReadOnlyNoDelete', (tester) async {
    await pump(tester, unitId: baseUnitId);

    final l = l10n();
    expect(find.text(l.unitsFormFactorBaseFixed), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.ancestor(
              of: find.text(factorLabel()),
              matching: find.byType(TextField),
            ),
          )
          .readOnly,
      isTrue,
    );
    expect(find.text(l.unitsDelete), findsNothing);
  }, variant: localeVariant);

  testWidgets('Delete_ConfirmSendsP8_InUseShowsBanner', (tester) async {
    when(() => repository.deleteUnit(productId, boxUnitId))
        .thenAnswer((_) async => Err(conflict(ApiErrorCode.productUnitInUse)));
    await pump(tester, unitId: boxUnitId);

    await tester.tap(find.text(l10n().unitsDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n().unitsDeleteDialogTitle), findsOneWidget);
    await tester.tap(find.text(l10n().unitsDelete).last);
    await tester.pumpAndSettle();

    verify(() => repository.deleteUnit(productId, boxUnitId)).called(1);
    expect(find.byType(FormBanner), findsOneWidget);
    expect(find.text(l10n().errorProductUnitInUse), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_FormRenders', (tester) async {
    await pump(tester, unitId: boxUnitId, themeMode: ThemeMode.dark);

    expect(
      Theme.of(tester.element(find.byType(TextField).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
