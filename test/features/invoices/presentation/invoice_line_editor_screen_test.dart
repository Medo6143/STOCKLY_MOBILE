import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_notifier.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_line_editor_screen.dart';
import 'package:stockly/features/invoices/presentation/widgets/new_product_form.dart';
import 'package:stockly/features/invoices/presentation/widgets/product_picker_sheet.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/products_doubles.dart' as products;
import '../../../helpers/pump_app.dart';
import 'invoice_screen_harness.dart';

/// Design §11 InvoiceLineEditorScreen with the product picker: 4 states ×
/// ar/en, unit choice, new product, the draft-only save, dark.
void main() {
  late InvoiceMocks mocks;

  setUpAll(() {
    registerInvoiceFallbacks();
    products.registerProductFallbacks();
  });

  setUp(() {
    mocks = InvoiceMocks();
    when(() => mocks.catalog.getProduct(any()))
        .thenAnswer((_) async => Ok(products.detail()));
  });

  void answer(Future<Result<InvoiceDetail, Failure>> Function() result) =>
      when(() => mocks.invoices.getInvoice(invoiceId))
          .thenAnswer((_) => result());

  void catalogue(List<ProductListItem> items) => when(
    () => mocks.catalog.getProducts(
      any(),
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((_) async => Ok(products.page(items)));

  Future<void> pump(
    WidgetTester tester, {
    int lineNo = 1,
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpInvoiceScreen(
    tester,
    InvoiceLineEditorScreen(invoiceId: invoiceId, lineNo: lineNo),
    mocks: mocks,
    themeMode: themeMode,
  );

  InvoiceDraft draftOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(InvoiceLineEditorScreen)),
  ).read(invoiceReviewProvider(invoiceId)).requireValue.draft;

  testWidgets('Loading_TheInvoice', (tester) async {
    final pending = Completer<Result<InvoiceDetail, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_LoadFailure', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorNetwork), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_ReadOnlyInvoice', (tester) async {
    answer(() async => Ok(invoiceDetail(status: InvoiceStatus.confirmed)));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(l10n().invoiceReviewReadOnly), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_ExistingLine_PrefilledWithItsUnits', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(l10n().invoiceLineNo(ltrIsolate('1'))), findsOneWidget);
    expect(find.text('بنادول اكسترا ٢٠ قرص'), findsOneWidget);
    expect(find.text('10.000'), findsOneWidget);
    expect(find.text('36.00'), findsOneWidget);
    expect(find.text('B12'), findsOneWidget);
    expect(find.text('بنادول اكسترا'), findsOneWidget);
    expect(find.text('علبة'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Done_WritesTheDraftOnly', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, l10n().invoiceLineQuantity),
      '12',
    );
    await tester.tap(find.text(l10n().invoiceLineDone));
    await tester.pumpAndSettle();

    expect(draftOf(tester).lineByNo(1)!.quantity, quantity('12.000'));
    verifyNever(() => mocks.invoices.saveItems(any(), any()));
  }, variant: localeVariant);

  testWidgets('Invalid_FieldErrors', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester, lineNo: 2);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, l10n().invoiceLineQuantity),
      '0',
    );
    await tester.tap(find.text(l10n().invoiceLineDone));
    await tester.pumpAndSettle();

    expect(find.text(l10n().errorPrecisionNotPositive), findsOneWidget);
    expect(find.text(l10n().invoicesFieldRequired), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Picker_ChooseAProduct_UnitsOfThatProduct', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    catalogue([products.listItem()]);
    await pump(tester, lineNo: 2);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(TextButton, l10n().invoiceLineChooseProduct),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProductPickerSheet), findsOneWidget);
    await tester.tap(find.text('بنادول اكسترا'));
    await tester.pumpAndSettle();

    expect(find.text('بنادول اكسترا'), findsOneWidget);
    expect(find.text(l10n().invoiceLineUnit), findsOneWidget);
    expect(find.text('شريط'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Picker_NoMatch_CreateNewProduct', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    catalogue(const []);
    await pump(tester, lineNo: 2);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(TextButton, l10n().invoiceLineChooseProduct),
    );
    await tester.pumpAndSettle();
    expect(find.text(l10n().productPickerEmptyTitle), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n().productPickerCreateNew),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NewProductForm), findsOneWidget);
    expect(find.text('مرهم جلد ٣٠ جم'), findsNWidgets(2));
  }, variant: localeVariant);

  testWidgets('Dark_Data', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester, lineNo: 3, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(NewProductForm), findsOneWidget);
    expect(find.text('سيتال شراب'), findsOneWidget);
  }, variant: localeVariant);
}
