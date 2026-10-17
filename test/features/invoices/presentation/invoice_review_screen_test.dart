import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_review_screen.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_line_tile.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'invoice_screen_harness.dart';

/// Design §11 InvoiceReviewScreen and the review rules: 4 states × ar/en,
/// save, line errors, read-only, RTL, dark.
void main() {
  late InvoiceMocks mocks;

  setUpAll(registerInvoiceFallbacks);
  setUp(() => mocks = InvoiceMocks());

  void answer(Future<Result<InvoiceDetail, Failure>> Function() result) =>
      when(() => mocks.invoices.getInvoice(invoiceId))
          .thenAnswer((_) => result());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpInvoiceScreen(
    tester,
    const InvoiceReviewScreen(invoiceId: invoiceId),
    mocks: mocks,
    themeMode: themeMode,
  );

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<InvoiceDetail, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().invoiceReviewTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_RetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    answer(() async => Ok(invoiceDetail()));
    await tester.tap(find.text(l10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceLineTile), findsNWidgets(3));
  }, variant: localeVariant);

  testWidgets('Empty_NoLinesRead_AddLineOpensTheEditor', (tester) async {
    answer(() async => Ok(invoiceDetail(items: const [])));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(l10n().invoiceReviewEmptyTitle), findsOneWidget);
    expect(find.text(l10n().invoiceReviewEmptyBody), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, l10n().invoiceReviewAddLine),
    );
    await tester.pumpAndSettle();
    expect(navigatedTo(RouteNames.invoiceLineEdit), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_HeaderWarningsAndLines', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = l10n();
    expect(find.text('شركة الأدوية المتحدة'), findsOneWidget);
    expect(find.text('INV-1043'), findsOneWidget);
    expect(find.text('1250.00'), findsOneWidget);
    expect(find.text(l.invoicesWarningTotalMismatch), findsOneWidget);
    expect(find.byType(InvoiceLineTile), findsNWidgets(3));
    expect(find.text(l.invoiceLineUnresolved), findsOneWidget);
    expect(find.text(l.invoiceLineNewProduct('سيتال شراب')), findsOneWidget);
    expect(find.text(l.commonSave), findsOneWidget);
    expect(find.text(l.invoiceReviewAddLine), findsOneWidget);
    expectLeading(tester, find.byIcon(Icons.warning_amber_rounded));
  }, variant: localeVariant);

  testWidgets('Save_WithUnresolvedLine_HighlightsAndSendsNothing', (
    tester,
  ) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n().commonSave));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n().errorInvoiceLineProductRequired),
      findsAtLeastNWidgets(2),
    );
    verifyNever(() => mocks.invoices.saveItems(any(), any()));
  }, variant: localeVariant);

  testWidgets('Save_Ok_SnackbarAndServerDraft', (tester) async {
    final resolved = invoiceDetail(items: [invoiceItem()]);
    answer(() async => Ok(resolved));
    when(() => mocks.invoices.saveItems(any(), any()))
        .thenAnswer((_) async => Ok(resolved));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, l10n().invoiceSupplierLabel),
      'مورد جديد',
    );
    await tester.tap(find.text(l10n().commonSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n().invoiceReviewSaved), findsOneWidget);
    verify(() => mocks.invoices.saveItems(invoiceId, any())).called(1);
  }, variant: localeVariant);

  testWidgets('BadTotal_FieldErrorAndSaveDisabled', (tester) async {
    answer(() async => Ok(invoiceDetail(items: [invoiceItem()])));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, l10n().invoiceTotalLabel),
      '1.234',
    );
    await tester.pump();

    expect(find.text(l10n().errorPrecisionTooManyDecimals), findsOneWidget);
    final save = tester.widget<TextButton>(
      find.widgetWithText(TextButton, l10n().commonSave),
    );
    expect(save.onPressed, isNull);
  }, variant: localeVariant);

  testWidgets('TapLine_OpensTheEditor_RemoveLine', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n().invoiceLineRemove).first);
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceLineTile), findsNWidgets(2));

    await tester.tap(find.byType(InvoiceLineTile).first);
    await tester.pumpAndSettle();
    expect(navigatedTo(RouteNames.invoiceLineEdit), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Confirmed_ReadOnly', (tester) async {
    answer(() async => Ok(invoiceDetail(status: InvoiceStatus.confirmed)));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text(l10n().invoiceReviewReadOnly), findsOneWidget);
    expect(find.text(l10n().commonSave), findsNothing);
    expect(find.byTooltip(l10n().invoiceLineRemove), findsNothing);
  }, variant: localeVariant);

  testWidgets('Dark_Data', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(InvoiceLineTile), findsNWidgets(3));
  }, variant: localeVariant);
}
