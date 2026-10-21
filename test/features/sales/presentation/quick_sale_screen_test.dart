import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/media/barcode_scanner.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_lookup.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';
import 'package:stockly/features/sales/presentation/screens/quick_sale_screen.dart';
import 'package:stockly/features/sales/presentation/widgets/barcode_entry_field.dart';
import 'package:stockly/features/sales/presentation/widgets/cart_line_tile.dart';
import 'package:stockly/features/sales/presentation/widgets/sale_total_bar.dart';

import '../../../helpers/dashboard_doubles.dart';
import '../../../helpers/products_doubles.dart' as products;
import '../../../helpers/pump_app.dart';
import '../../../helpers/routed_screen.dart';
import '../../../helpers/sales_doubles.dart';
import '../../../helpers/test_doubles.dart';

const String _barcode = '6221234567890';

/// Design §11 QuickSaleScreen and §6.8: 4 states × ar/en (empty cart,
/// lookup and submit progress, lookup/submit failures and the locked cart,
/// the cart), keyboard-wedge entry, search, camera, unit picker, RTL and
/// dark.
void main() {
  late MockSalesRepository sales;
  late products.MockProductsRepository catalog;
  late MockBarcodeScanner scanner;
  late StreamController<String> reads;

  setUpAll(() {
    registerSaleFallbacks();
    products.registerProductFallbacks();
  });

  setUp(() {
    sales = MockSalesRepository();
    catalog = products.MockProductsRepository();
    scanner = MockBarcodeScanner();
    reads = StreamController<String>.broadcast();
    addTearDown(reads.close);
    when(scanner.scan).thenAnswer((_) => reads.stream);
    when(scanner.preview).thenReturn(const SizedBox.expand());
    when(scanner.dispose).thenAnswer((_) async {});
    when(() => sales.pendingSale(any())).thenAnswer((_) async => null);
    when(() => sales.discardPending(any())).thenAnswer((_) async {});
    when(() => catalog.lookupBarcode(_barcode)).thenAnswer(
      (_) async => Ok(
        ProductLookup(product: products.listItem(), unit: products.baseUnit),
      ),
    );
    when(() => catalog.getProduct(products.productId))
        .thenAnswer((_) async => Ok(products.detail()));
  });

  void answerSubmit(Result<SaleSubmission, Failure> result) => when(
    () => sales.submit(
      any(),
      shopId: any(named: 'shopId'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer((_) async => result);

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpRoutedScreen(
      tester,
      const QuickSaleScreen(),
      themeMode: themeMode,
      overrides: [
        salesRepositoryProvider.overrideWithValue(sales),
        productsRepositoryProvider.overrideWithValue(catalog),
        dashboardRepositoryProvider.overrideWithValue(quietDashboard()),
        barcodeScannerProvider.overrideWithValue(scanner),
        uuidGeneratorProvider.overrideWithValue(CountingUuidGenerator()),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> scan(WidgetTester tester, String barcode) async {
    await tester.enterText(find.byType(BarcodeEntryField), barcode);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('Empty_ScanOrSearch', (tester) async {
    await pump(tester);

    final l = routedL10n();
    expect(find.text(l.salesQuickSaleTitle), findsOneWidget);
    expect(find.text(l.salesCartEmptyTitle), findsOneWidget);
    expect(find.text(l.salesCartEmptyBody), findsOneWidget);
    expect(find.text(l.salesBarcodeLabel), findsOneWidget);
    expect(find.byType(SaleTotalBar), findsNothing);
    expectStartSide(tester, find.byIcon(Icons.qr_code_rounded));
  }, variant: localeVariant);

  testWidgets('Loading_LookupShowsProgress', (tester) async {
    final pending = Completer<Result<ProductLookup, Failure>>();
    when(() => catalog.lookupBarcode('slow')).thenAnswer((_) => pending.future);
    await pump(tester);

    await tester.enterText(find.byType(BarcodeEntryField), 'slow');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.complete(
      Ok(ProductLookup(product: products.listItem(), unit: products.baseUnit)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CartLineTile), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_UnknownBarcode', (tester) async {
    when(() => catalog.lookupBarcode('000'))
        .thenAnswer((_) async => const Err(products.productNotFound));
    await pump(tester);

    await scan(tester, '000');

    expect(find.text(routedL10n().salesBarcodeNotFound), findsOneWidget);
    expect(find.byType(CartLineTile), findsNothing);
  }, variant: localeVariant);

  testWidgets('Data_WedgeScansAddUpAndSubmitOpensTheSale', (tester) async {
    answerSubmit(Ok(SaleSubmission.created(sale())));
    await pump(tester);

    await scan(tester, _barcode);
    await scan(tester, _barcode);

    final l = routedL10n();
    expect(find.byType(CartLineTile), findsOneWidget);
    expect(find.text('بنادول اكسترا'), findsOneWidget);
    expect(find.widgetWithText(TextField, '2'), findsOneWidget);
    expect(find.text(l.salesTotalLabel), findsOneWidget);
    expect(find.textContaining('30.00'), findsWidgets);

    await tester.tap(find.text(l.salesSubmit));
    await tester.pumpAndSettle();

    expect(routedTo(RouteNames.saleDetail), findsOneWidget);
    expect(find.text('/sale/$saleId'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('KeyboardOpen_SubmitStaysAboveIt', (tester) async {
    // The barcode field keeps focus after every scan, so the keyboard is up
    // most of the time: the submit button must not be under it.
    const keyboard = 320.0;
    tester.view.viewInsets = FakeViewPadding(
      bottom: keyboard * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    answerSubmit(Ok(SaleSubmission.created(sale())));
    await pump(tester);

    await scan(tester, _barcode);

    final l = routedL10n();
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final submit = tester.getRect(find.text(l.salesSubmit));
    expect(submit.bottom, lessThanOrEqualTo(screenHeight - keyboard));
    await tester.tap(find.text(l.salesSubmit));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.saleDetail), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_AlreadyRecordedOpensTheSaleWithTheInfo', (tester) async {
    answerSubmit(Ok(SaleSubmission.alreadyRecorded(sale())));
    await pump(tester);
    await scan(tester, _barcode);

    await tester.tap(find.text(routedL10n().salesSubmit));
    await tester.pumpAndSettle();

    expect(find.text('/sale/$saleId?repeat=true'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_InvalidQuantityBlocksTheSubmit', (tester) async {
    await pump(tester);
    await scan(tester, _barcode);

    final l = routedL10n();
    await tester.enterText(
      find.widgetWithText(TextField, l.salesQuantityLabel),
      '0',
    );
    await tester.pumpAndSettle();

    expect(find.text(l.errorPrecisionNotPositive), findsOneWidget);
    final submit = tester.widget<SaleTotalBar>(find.byType(SaleTotalBar));
    expect(submit.onSubmit, isNull);
  }, variant: localeVariant);

  testWidgets('Error_DefiniteFailureBannerCartKept', (tester) async {
    answerSubmit(const Err(archivedProduct));
    await pump(tester);
    await scan(tester, _barcode);

    await tester.tap(find.text(routedL10n().salesSubmit));
    await tester.pumpAndSettle();

    expect(find.text(routedL10n().errorSaleArchivedProduct), findsOneWidget);
    expect(find.byType(CartLineTile), findsOneWidget);
    expect(find.byType(BarcodeEntryField), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_UnknownOutcomeLocksUntilRetry', (tester) async {
    answerSubmit(const Err(NetworkFailure()));
    await pump(tester);
    await scan(tester, _barcode);

    final l = routedL10n();
    await tester.tap(find.text(l.salesSubmit));
    await tester.pumpAndSettle();

    expect(find.text(l.salesLockedTitle), findsOneWidget);
    expect(find.text(l.salesLockedBody), findsOneWidget);
    expect(find.byType(BarcodeEntryField), findsNothing);
    expect(find.byType(SaleTotalBar), findsNothing);
    final quantity = tester.widget<TextField>(
      find.widgetWithText(TextField, l.salesQuantityLabel),
    );
    expect(quantity.enabled, isFalse);

    answerSubmit(Ok(SaleSubmission.alreadyRecorded(sale())));
    await tester.tap(find.text(l.commonRetry));
    await tester.pumpAndSettle();

    final requests = verify(
      () => sales.submit(
        captureAny(),
        shopId: any(named: 'shopId'),
        userId: any(named: 'userId'),
      ),
    ).captured.cast<SaleRequest>();
    expect(requests, hasLength(2));
    expect(requests.first, requests.last);
    expect(find.text('/sale/$saleId?repeat=true'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Locked_DiscardAsksThenEmptiesTheCart', (tester) async {
    answerSubmit(const Err(TimeoutFailure()));
    await pump(tester);
    await scan(tester, _barcode);
    final l = routedL10n();
    await tester.tap(find.text(l.salesSubmit));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l.salesDiscard));
    await tester.pumpAndSettle();
    expect(find.text(l.salesDiscardTitle), findsOneWidget);
    await tester.tap(find.text(l.salesDiscard).last);
    await tester.pumpAndSettle();

    verify(() => sales.discardPending(any())).called(1);
    expect(find.text(l.salesCartEmptyTitle), findsOneWidget);
    expect(find.byType(BarcodeEntryField), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Restore_PendingSaleOpensLocked', (tester) async {
    when(() => sales.pendingSale(any())).thenAnswer((_) async => pendingSale());
    await pump(tester);

    final l = routedL10n();
    expect(find.text(l.salesLockedTitle), findsOneWidget);
    expect(find.text(l.salesItemCount(1)), findsOneWidget);
    expect(find.text(l.salesCartEmptyTitle), findsNothing);
  }, variant: localeVariant);

  testWidgets('Search_AddsThePickedProduct', (tester) async {
    when(
      () => catalog.getProducts(
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Ok(products.page<ProductListItem>([products.listItem()])),
    );
    await pump(tester);

    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text(routedL10n().salesSearchTitle), findsWidgets);
    await tester.tap(find.text('بنادول اكسترا'));
    await tester.pumpAndSettle();

    expect(find.byType(CartLineTile), findsOneWidget);
    verify(() => catalog.getProduct(products.productId)).called(1);
  }, variant: localeVariant);

  testWidgets('Camera_TheFirstBarcodeRead', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    expect(find.text(routedL10n().salesCameraHint), findsOneWidget);
    reads.add(_barcode);
    await tester.pumpAndSettle();

    expect(find.text(routedL10n().salesCameraHint), findsNothing);
    expect(find.byType(CartLineTile), findsOneWidget);
    verify(() => catalog.lookupBarcode(_barcode)).called(1);
  }, variant: localeVariant);

  testWidgets('UnitPicker_LoadsTheUnitsAndSwitches', (tester) async {
    await pump(tester);
    await scan(tester, _barcode);

    await tester.tap(find.widgetWithText(OutlinedButton, 'شريط'));
    await tester.pumpAndSettle();
    expect(find.text(routedL10n().salesChooseUnit), findsOneWidget);
    await tester.tap(find.text('علبة'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'علبة'), findsOneWidget);
    expect(find.textContaining('40.00'), findsWidgets);
  }, variant: localeVariant);

  testWidgets('Rtl_TheCartLineReadsFromTheStart', (tester) async {
    await pump(tester);
    await scan(tester, _barcode);

    expectStartSide(tester, find.text('بنادول اكسترا'));
    expect(find.byType(FormBanner), findsNothing);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pump(tester, themeMode: ThemeMode.dark);
    await scan(tester, _barcode);

    expect(find.byType(CartLineTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
