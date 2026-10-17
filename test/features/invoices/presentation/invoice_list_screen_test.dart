import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/screens/invoice_list_screen.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_list_tile.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'invoice_screen_harness.dart';

/// Design §11 InvoiceListScreen: 4 states × ar/en, the pending card, the
/// filter, RTL, dark.
void main() {
  late InvoiceMocks mocks;

  setUp(() {
    mocks = InvoiceMocks();
    when(() => mocks.queue.watchPendingCount(any()))
        .thenAnswer((_) => Stream.value(0));
  });

  void answer(Future<Result<Paged<InvoiceListItem>, Failure>> result) => when(
    () => mocks.invoices.getInvoices(
      status: any(named: 'status'),
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((_) => result);

  Future<Result<Paged<InvoiceListItem>, Failure>> page(
    List<InvoiceListItem> items,
  ) async =>
      Ok(Paged(items: items, page: 1, pageSize: 20, totalCount: items.length));

  testWidgets('Loading_Indicator', (tester) async {
    answer(Completer<Result<Paged<InvoiceListItem>, Failure>>().future);
    await pumpInvoiceScreen(tester, const InvoiceListScreen(), mocks: mocks);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().navInvoices), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_NoInvoicesYet_ScanOpensTheCamera', (tester) async {
    answer(page(const []));
    await pumpInvoiceScreen(tester, const InvoiceListScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    expect(find.text(l10n().invoicesListEmptyTitle), findsOneWidget);
    expect(find.text(l10n().invoicesListEmptyBody), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(navigatedTo(RouteNames.scanCapture), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_WithAFilter_FilterText', (tester) async {
    answer(page(const []));
    await pumpInvoiceScreen(
      tester,
      const InvoiceListScreen(initialStatus: InvoiceStatus.failed),
      mocks: mocks,
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n().invoicesListFilteredEmptyTitle), findsOneWidget);
    verify(
      () => mocks.invoices.getInvoices(
        status: InvoiceStatus.failed,
        page: 1,
        pageSize: 20,
      ),
    ).called(1);
  }, variant: localeVariant);

  testWidgets('Error_MessageAndRetry', (tester) async {
    answer(Future.value(const Err(NetworkFailure())));
    await pumpInvoiceScreen(tester, const InvoiceListScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorNetwork), findsOneWidget);
    answer(page([invoiceListItem()]));
    await tester.tap(find.text(l10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(InvoiceListTile), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_TileWithStatusAndCount_TapOpensTheInvoice', (tester) async {
    answer(page([invoiceListItem()]));
    await pumpInvoiceScreen(tester, const InvoiceListScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    expect(find.text('شركة الأدوية المتحدة'), findsOneWidget);
    expect(
      find.text(l10n().invoicesStatusNeedsReview),
      findsAtLeastNWidgets(2),
    );
    expect(find.textContaining(l10n().invoicesItemCount(3)), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expectLeading(tester, find.text('شركة الأدوية المتحدة'));

    await tester.tap(find.byType(InvoiceListTile));
    await tester.pumpAndSettle();
    expect(navigatedTo(RouteNames.invoiceDetail), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_PendingScansCard_OpensTheQueue', (tester) async {
    when(() => mocks.queue.watchPendingCount(any()))
        .thenAnswer((_) => Stream.value(2));
    answer(page([invoiceListItem()]));
    await pumpInvoiceScreen(tester, const InvoiceListScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    expect(find.text(l10n().scanQueuePendingCount(2)), findsOneWidget);
    await tester.tap(find.text(l10n().scanQueuePendingCount(2)));
    await tester.pumpAndSettle();
    expect(navigatedTo(RouteNames.scanQueue), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Filter_ReloadsWithTheStatus', (tester) async {
    answer(page([invoiceListItem()]));
    await pumpInvoiceScreen(tester, const InvoiceListScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ChoiceChip, l10n().invoicesStatusConfirmed),
    );
    await tester.pumpAndSettle();

    verify(
      () => mocks.invoices.getInvoices(
        status: InvoiceStatus.confirmed,
        page: 1,
        pageSize: 20,
      ),
    ).called(1);
  }, variant: localeVariant);

  testWidgets('Offline_Banner', (tester) async {
    answer(page([invoiceListItem()]));
    await pumpInvoiceScreen(
      tester,
      const InvoiceListScreen(),
      mocks: mocks,
      online: false,
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n().commonOfflineBanner), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_Data', (tester) async {
    answer(page([invoiceListItem(status: InvoiceStatus.failed)]));
    await pumpInvoiceScreen(
      tester,
      const InvoiceListScreen(),
      mocks: mocks,
      themeMode: ThemeMode.dark,
    );
    await tester.pumpAndSettle();

    expect(find.byType(InvoiceListTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
