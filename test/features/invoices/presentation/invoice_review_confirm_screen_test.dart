import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_review_screen.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'invoice_screen_harness.dart';

/// Design §11 Sprint 4 confirm on `InvoiceReviewScreen`: "Confirming…",
/// line and network failures, save-if-dirty first, the confirmed invoice
/// opens its detail, read-only invoices have no confirm. ar/en, dark.
void main() {
  late InvoiceMocks mocks;
  final resolved = invoiceDetail(items: [invoiceItem()]);
  final confirmed = invoiceDetail(
    status: InvoiceStatus.confirmed,
    items: [invoiceItem()],
  );

  setUpAll(registerInvoiceFallbacks);
  setUp(() => mocks = InvoiceMocks());

  void answer(InvoiceDetail invoice) =>
      when(() => mocks.invoices.getInvoice(invoiceId))
          .thenAnswer((_) async => Ok(invoice));

  void answerConfirm(Future<Result<InvoiceDetail, Failure>> Function() r) =>
      when(() => mocks.invoices.confirm(invoiceId)).thenAnswer((_) => r());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpInvoiceScreen(
      tester,
      const InvoiceReviewScreen(invoiceId: invoiceId),
      mocks: mocks,
      themeMode: themeMode,
      routeName: RouteNames.invoiceReview,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Confirm_OpensTheConfirmedInvoice', (tester) async {
    answer(resolved);
    answerConfirm(() async => Ok(confirmed));
    await pump(tester);

    await tester.tap(find.text(l10n().invoiceReviewConfirm));
    await tester.pumpAndSettle();

    verify(() => mocks.invoices.confirm(invoiceId)).called(1);
    verifyNever(() => mocks.invoices.saveItems(any(), any()));
    expect(navigatedTo(RouteNames.invoiceDetail), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Loading_Confirming', (tester) async {
    answer(resolved);
    final pending = Completer<Result<InvoiceDetail, Failure>>();
    answerConfirm(() => pending.future);
    await pump(tester);

    await tester.tap(find.text(l10n().invoiceReviewConfirm));
    await tester.pump();

    expect(find.text(l10n().invoiceReviewConfirming), findsNWidgets(2));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.byIcon(Icons.inventory_rounded),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
    pending.complete(Ok(confirmed));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Error_UnresolvedLineHighlightedNothingSent', (tester) async {
    answer(invoiceDetail());
    await pump(tester);

    await tester.tap(find.text(l10n().invoiceReviewConfirm));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n().errorInvoiceLineProductRequired),
      findsAtLeastNWidgets(2),
    );
    verifyNever(() => mocks.invoices.confirm(any()));
  }, variant: localeVariant);

  testWidgets('Error_NetworkBannerAndRetry', (tester) async {
    answer(resolved);
    answerConfirm(() async => const Err(NetworkFailure()));
    await pump(tester);

    await tester.tap(find.text(l10n().invoiceReviewConfirm));
    await tester.pumpAndSettle();
    expect(find.text(l10n().errorNetwork), findsOneWidget);

    answerConfirm(() async => Ok(confirmed));
    await tester.tap(find.text(l10n().invoiceReviewConfirm));
    await tester.pumpAndSettle();
    expect(navigatedTo(RouteNames.invoiceDetail), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dirty_SavedBeforeTheConfirm', (tester) async {
    answer(resolved);
    when(() => mocks.invoices.saveItems(any(), any()))
        .thenAnswer((_) async => Ok(resolved));
    answerConfirm(() async => Ok(confirmed));
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, l10n().invoiceSupplierLabel),
      'مورد جديد',
    );
    await tester.tap(find.text(l10n().invoiceReviewConfirm));
    await tester.pumpAndSettle();

    verifyInOrder([
      () => mocks.invoices.saveItems(invoiceId, any()),
      () => mocks.invoices.confirm(invoiceId),
    ]);
  }, variant: localeVariant);

  testWidgets('ReadOnly_NoConfirm', (tester) async {
    answer(confirmed);
    await pump(tester);

    expect(find.text(l10n().invoiceReviewConfirm), findsNothing);
  }, variant: localeVariant);

  testWidgets('Dark_ConfirmBar', (tester) async {
    answer(resolved);
    await pump(tester, themeMode: ThemeMode.dark);

    expect(find.text(l10n().invoiceReviewConfirm), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
