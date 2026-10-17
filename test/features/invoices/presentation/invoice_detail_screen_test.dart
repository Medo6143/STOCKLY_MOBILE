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
import 'package:stockly/features/invoices/presentation/screens/invoice_confirmed_view.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_detail_screen.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_failed_view.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_processing_view.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_line_tile.dart';
import 'package:stockly/features/invoices/presentation/widgets/reading_invoice_animation.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'invoice_screen_harness.dart';

/// Design §11 InvoiceDetailScreen and its views: 4 states × ar/en, the
/// status routing, reduce motion, dark.
void main() {
  late InvoiceMocks mocks;

  setUp(() => mocks = InvoiceMocks());

  void answer(Future<Result<InvoiceDetail, Failure>> Function() result) =>
      when(() => mocks.invoices.getInvoice(invoiceId))
          .thenAnswer((_) => result());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    bool disableAnimations = false,
  }) => pumpInvoiceScreen(
    tester,
    const InvoiceDetailScreen(invoiceId: invoiceId),
    mocks: mocks,
    themeMode: themeMode,
    disableAnimations: disableAnimations,
    routeName: RouteNames.invoiceDetail,
  );

  testWidgets('Loading_WhileI3Runs', (tester) async {
    final pending = Completer<Result<InvoiceDetail, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().invoiceDetailTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_NotFoundWithBackAndRetry', (tester) async {
    answer(() async => const Err(invoiceNotFound));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorInvoiceNotFound), findsOneWidget);
    expect(find.text(l10n().commonBack), findsOneWidget);
    expect(find.text(l10n().commonRetry), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_Confirmed_ReadOnlyLines', (tester) async {
    answer(() async => Ok(invoiceDetail(status: InvoiceStatus.confirmed)));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(InvoiceConfirmedView), findsOneWidget);
    expect(find.text(l10n().invoiceConfirmedTitle), findsOneWidget);
    expect(find.byType(InvoiceLineTile), findsNWidgets(3));
    expect(find.text(l10n().invoicesWarningTotalMismatch), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  }, variant: localeVariant);

  testWidgets('Data_Failed_ReasonAndScanAgain', (tester) async {
    answer(
      () async => Ok(
        invoiceDetail(
          status: InvoiceStatus.failed,
          items: const [],
          failureReason: 'blurry',
        ),
      ),
    );
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(InvoiceFailedView), findsOneWidget);
    expect(find.text(l10n().invoiceFailedReason('blurry')), findsOneWidget);
    await tester.tap(find.text(l10n().invoiceFailedScanAgain));
    await tester.pumpAndSettle();
    expect(navigatedTo(RouteNames.scanCapture), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_Processing_StaticUnderReduceMotion', (tester) async {
    answer(() async => Ok(invoiceDetail(status: InvoiceStatus.processing)));
    await pump(tester, disableAnimations: true);
    await tester.pump();
    await tester.pump();

    expect(find.byType(InvoiceProcessingView), findsOneWidget);
    expect(find.byType(ReadingInvoiceAnimation), findsOneWidget);
    expect(find.text(l10n().invoiceProcessingTitle), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: localeVariant);

  testWidgets('Processing_ThenNeedsReview_OpensTheReview', (tester) async {
    var calls = 0;
    answer(() async {
      calls++;
      return Ok(
        calls < 3
            ? invoiceDetail(status: InvoiceStatus.processing)
            : invoiceDetail(),
      );
    });
    await pump(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text(l10n().invoiceProcessingTitle), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(navigatedTo(RouteNames.invoiceReview), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Processing60s_StillProcessingWithRefresh', (tester) async {
    answer(() async => Ok(invoiceDetail(status: InvoiceStatus.processing)));
    await pump(tester, disableAnimations: true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();

    expect(find.text(l10n().invoiceProcessingStillTitle), findsOneWidget);
    expect(find.text(l10n().invoiceProcessingRefresh), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  }, variant: localeVariant);

  testWidgets('Data_NeedsReview_OpensTheReviewOnce', (tester) async {
    answer(() async => Ok(invoiceDetail()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(navigatedTo(RouteNames.invoiceReview), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_Confirmed', (tester) async {
    answer(() async => Ok(invoiceDetail(status: InvoiceStatus.confirmed)));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(InvoiceConfirmedView), findsOneWidget);
  }, variant: localeVariant);
}
