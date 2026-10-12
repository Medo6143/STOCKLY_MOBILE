import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/presentation/screens/product_form_screen.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'screen_harness.dart';

/// Design §11 `ProductFormScreen` (create and edit): 4 states × ar/en,
/// Owner-only opening stock, field errors, RTL, dark.
void main() {
  late MockProductsRepository repository;

  setUpAll(registerProductFallbacks);
  setUp(() => repository = MockProductsRepository());

  Future<void> pumpCreate(
    WidgetTester tester, {
    Session? session,
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpProductScreen(
    tester,
    const ProductFormScreen(),
    repository: repository,
    session: session,
    themeMode: themeMode,
  );

  Future<void> pumpEdit(WidgetTester tester) => pumpProductScreen(
    tester,
    const ProductFormScreen(productId: productId),
    repository: repository,
  );

  Future<void> fillCreate(WidgetTester tester) async {
    final l = l10n();
    await enterField(tester, l.productsFormName, 'سيتال');
    await enterField(tester, l.productsFormBaseUnitName, 'زجاجة');
    await enterField(tester, l.productsFormCostPrice, '20.5');
    await enterField(tester, l.productsFormSellPrice, '٢٥');
  }

  Finder submit() => find.byType(FilledButton);

  testWidgets('Empty_CreateIsTheBlankForm_OwnerSeesOpeningStock', (
    tester,
  ) async {
    await pumpCreate(tester);

    final l = l10n();
    expect(find.text(l.productsFormCreateTitle), findsOneWidget);
    for (final label in [
      l.productsFormName,
      l.productsFormBaseUnitName,
      l.productsFormCostPrice,
      l.productsFormSellPrice,
      l.productsFormThreshold,
      l.productsFormOpeningQuantity,
      l.productsFormBarcode,
      l.productsFormCategory,
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(fieldError(tester, label), isNull);
    }
    expect(find.text(l.productsFormSubmitCreate), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_Staff_NoOpeningStockField', (tester) async {
    await pumpCreate(tester, session: staffSession);

    expect(find.text(l10n().productsFormOpeningQuantity), findsNothing);
  }, variant: localeVariant);

  testWidgets('Loading_EditPreload', (tester) async {
    final pending = Completer<Result<ProductDetail, Failure>>();
    when(() => repository.getProduct(productId))
        .thenAnswer((_) => pending.future);

    await pumpEdit(tester);

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().productsFormEditTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Loading_SubmitSpinnerAndFieldsDisabled', (tester) async {
    final pending = Completer<Result<ProductDetail, Failure>>();
    when(() => repository.createProduct(any()))
        .thenAnswer((_) => pending.future);
    await pumpCreate(tester);
    await fillCreate(tester);

    await tester.tap(submit());
    await tester.pump();

    expect(
      find.descendant(
        of: submit(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(submit()).onPressed, isNull);
    pending.complete(const Err(NetworkFailure()));
    await tester.pump();
    expect(find.byType(FormBanner), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_LocalIssuesUnderTheirFields', (tester) async {
    await pumpCreate(tester);

    await enterField(tester, l10n().productsFormCostPrice, '1.234');
    await tester.tap(submit());
    await tester.pump();

    final l = l10n();
    expect(fieldError(tester, l.productsFormName), l.productsFieldRequired);
    expect(
      fieldError(tester, l.productsFormCostPrice),
      l.errorPrecisionTooManyDecimals,
    );
    verifyNever(() => repository.createProduct(any()));
  }, variant: localeVariant);

  testWidgets('Error_DuplicateBarcodeUnderBarcode_OwnerOnlyInBanner', (
    tester,
  ) async {
    when(() => repository.createProduct(any())).thenAnswer(
      (_) async => Err(conflict(ApiErrorCode.productDuplicateBarcode)),
    );
    await pumpCreate(tester);
    await fillCreate(tester);

    await tester.tap(submit());
    await tester.pump();

    final l = l10n();
    expect(
      fieldError(tester, l.productsFormBarcode),
      l.errorProductDuplicateBarcode,
    );

    when(() => repository.createProduct(any())).thenAnswer(
      (_) async => const Err(
        ForbiddenFailure(
          ApiErrorCode.productOpeningStockOwnerOnly,
          ApiProblemInfo(status: 403),
        ),
      ),
    );
    await tester.tap(submit());
    await tester.pump();
    expect(find.byType(FormBanner), findsOneWidget);
    expect(find.text(l.errorProductOpeningStockOwnerOnly), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_EditOfAnArchivedProduct_CannotBeEdited', (tester) async {
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => Ok(detail(isArchived: true)));

    await pumpEdit(tester);
    await tester.pump();

    expect(find.text(l10n().productsFormArchivedTitle), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  }, variant: localeVariant);

  testWidgets('Data_EditFormFilled_SavesP4', (tester) async {
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => Ok(detail()));
    when(() => repository.updateProduct(productId, any()))
        .thenAnswer((_) async => Ok(detail()));

    await pumpEdit(tester);
    await tester.pump();

    final l = l10n();
    expect(find.text('بنادول اكسترا'), findsOneWidget);
    expect(find.text('12.50'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text(l.productsFormBaseUnitName), findsNothing);
    expect(find.text(l.productsFormOpeningQuantity), findsNothing);
    await enterField(tester, l.productsFormCostPrice, '13');
    await tester.tap(submit());
    await tester.pump();

    final update =
        verify(() => repository.updateProduct(productId, captureAny()))
                .captured
                .single
            as ProductUpdate;
    expect(update.costPrice.toApi(), '13.00');
    expect(update.barcode, '6221234567890');
    expect(find.text(l.productsSaved), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_CreateOk_OpensTheNewProduct', (tester) async {
    when(() => repository.createProduct(any()))
        .thenAnswer((_) async => Ok(detail()));
    await pumpProductRouter(
      tester,
      location: '/products/new',
      repository: repository,
      routes: [
        GoRoute(
          path: '/products/new',
          builder: (context, state) => const ProductFormScreen(),
        ),
        GoRoute(
          path: '/products/:productId',
          name: RouteNames.productDetail,
          builder: (context, state) =>
              Text('detail ${state.pathParameters['productId']}'),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await fillCreate(tester);
    await enterField(tester, l10n().productsFormOpeningQuantity, '24');

    await tester.tap(submit());
    await tester.pumpAndSettle();

    expect(find.text('detail $productId'), findsOneWidget);
    final draft =
        verify(() => repository.createProduct(captureAny())).captured.single
            as ProductDraft;
    expect(draft.baseUnitSellPrice.toApi(), '25.00');
    expect(draft.openingQuantity?.toApi(), '24.000');
  }, variant: localeVariant);

  testWidgets('Rtl_FieldsFollowTheLanguage', (tester) async {
    await pumpCreate(tester);

    expectLeading(tester, find.text(l10n().productsFormName));
  }, variant: localeVariant);

  testWidgets('Dark_FormRenders', (tester) async {
    await pumpCreate(tester, themeMode: ThemeMode.dark);

    expect(
      Theme.of(tester.element(find.byType(TextField).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
