import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/presentation/screens/scan_queue_screen.dart';
import 'package:stockly/features/invoices/presentation/widgets/pending_scan_tile.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/test_doubles.dart';
import 'invoice_screen_harness.dart';

/// Design §6.6 and §11 ScanQueueScreen: 4 states × ar/en, status texts,
/// actions, offline banner, dark.
void main() {
  late InvoiceMocks mocks;
  final now = FakeClock().now();

  setUp(() => mocks = InvoiceMocks());

  void scans(Stream<List<PendingScan>> stream) =>
      when(() => mocks.queue.watchPending(any())).thenAnswer((_) => stream);

  testWidgets('Loading_FirstDatabaseRead', (tester) async {
    scans(StreamController<List<PendingScan>>().stream);
    await pumpInvoiceScreen(tester, const ScanQueueScreen(), mocks: mocks);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().scanQueueTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_AllUploaded', (tester) async {
    scans(Stream.value(const []));
    await pumpInvoiceScreen(tester, const ScanQueueScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    expect(find.text(l10n().scanQueueEmptyTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_LocalStorage', (tester) async {
    scans(Stream.error(const LocalFailure(LocalFailureReason.storage)));
    await pumpInvoiceScreen(tester, const ScanQueueScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorLocalStorage), findsOneWidget);
    expect(find.text(l10n().commonRetry), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_StatusTextPerState', (tester) async {
    scans(
      Stream.value([
        pendingScan(id: 'a'),
        pendingScan(id: 'b', status: PendingScanStatus.uploading),
        pendingScan(
          id: 'c',
          status: PendingScanStatus.rateLimited,
          nextAttemptAt: now.add(const Duration(seconds: 42)),
        ),
        pendingScan(id: 'd', status: PendingScanStatus.quotaExceeded),
        pendingScan(
          id: 'e',
          status: PendingScanStatus.failedPermanent,
          lastErrorCode: 'Invoice.ImageTooLarge',
        ),
      ]),
    );
    await pumpInvoiceScreen(tester, const ScanQueueScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    final l = l10n();
    expect(find.byType(PendingScanTile), findsNWidgets(5));
    expect(find.text(l.scanQueueStatusQueued), findsOneWidget);
    expect(find.text(l.scanQueueStatusUploading), findsOneWidget);
    expect(
      find.text(l.scanQueueStatusRateLimited(ltrIsolate('42'))),
      findsOneWidget,
    );
    expect(find.text(l.scanQueueStatusQuotaExceeded), findsOneWidget);
    expect(find.text(l.errorInvoiceImageTooLarge), findsOneWidget);
    expect(find.text(l.scanCaptureRetake), findsOneWidget);
    expect(find.text(l.commonDelete), findsNWidgets(4));
  }, variant: localeVariant);

  testWidgets('Offline_WaitingForInternetAndBanner', (tester) async {
    scans(
      Stream.value([
        pendingScan(),
        pendingScan(
          id: 'b',
          status: PendingScanStatus.waitingRetry,
          nextAttemptAt: now.add(const Duration(minutes: 1)),
        ),
      ]),
    );
    await pumpInvoiceScreen(
      tester,
      const ScanQueueScreen(),
      mocks: mocks,
      online: false,
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n().commonOfflineBanner), findsOneWidget);
    expect(
      find.text(l10n().scanQueueStatusWaitingForInternet),
      findsNWidgets(2),
    );
  }, variant: localeVariant);

  testWidgets('RetryNow_ForcedRun', (tester) async {
    scans(Stream.value([pendingScan()]));
    when(() => mocks.queue.runQueue(force: true)).thenAnswer((_) async => null);
    await pumpInvoiceScreen(tester, const ScanQueueScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n().scanQueueRetryNow));
    await tester.pumpAndSettle();

    verify(() => mocks.queue.runQueue(force: true)).called(1);
  }, variant: localeVariant);

  testWidgets('Delete_AsksThenDeletes', (tester) async {
    scans(Stream.value([pendingScan()]));
    when(() => mocks.queue.delete(clientRequestId))
        .thenAnswer((_) async => const Ok(null));
    await pumpInvoiceScreen(tester, const ScanQueueScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n().commonDelete));
    await tester.pumpAndSettle();
    expect(find.text(l10n().scanQueueDeleteTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, l10n().commonDelete));
    await tester.pumpAndSettle();

    verify(() => mocks.queue.delete(clientRequestId)).called(1);
  }, variant: localeVariant);

  testWidgets('Retake_DeletesAndOpensTheCamera', (tester) async {
    scans(
      Stream.value([
        pendingScan(
          status: PendingScanStatus.failedPermanent,
          lastErrorCode: 'storage',
        ),
      ]),
    );
    when(() => mocks.queue.delete(clientRequestId))
        .thenAnswer((_) async => const Ok(null));
    await pumpInvoiceScreen(tester, const ScanQueueScreen(), mocks: mocks);
    await tester.pumpAndSettle();
    expect(find.text(l10n().errorLocalStorage), findsOneWidget);

    await tester.tap(find.text(l10n().scanCaptureRetake));
    await tester.pumpAndSettle();

    expect(navigatedTo(RouteNames.scanCapture), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_Data', (tester) async {
    scans(Stream.value([pendingScan()]));
    await pumpInvoiceScreen(
      tester,
      const ScanQueueScreen(),
      mocks: mocks,
      themeMode: ThemeMode.dark,
    );
    await tester.pumpAndSettle();

    expect(find.byType(PendingScanTile), findsOneWidget);
  }, variant: localeVariant);
}
