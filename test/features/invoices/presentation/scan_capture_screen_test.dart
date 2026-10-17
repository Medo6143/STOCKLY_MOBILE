import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';
import 'package:stockly/features/invoices/presentation/screens/scan_capture_screen.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'invoice_screen_harness.dart';

/// Design §6.6 and §11 ScanCaptureScreen: 4 states × ar/en, upload
/// outcomes, dark.
void main() {
  late InvoiceMocks mocks;

  setUpAll(registerInvoiceFallbacks);
  setUp(() => mocks = InvoiceMocks());

  void photo(Future<Result<CapturedImage?, Failure>> result) =>
      when(() => mocks.photos.takePhoto()).thenAnswer((_) => result);

  void queued() => when(
    () => mocks.queue.enqueue(
      any(),
      shopId: any(named: 'shopId'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer((_) async => Ok(pendingScan()));

  Future<void> openPreview(WidgetTester tester) async {
    photo(Future.value(const Ok(CapturedImage(path: 'missing.jpg'))));
    await pumpInvoiceScreen(tester, const ScanCaptureScreen(), mocks: mocks);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n().scanCaptureTakePhoto));
    await tester.pumpAndSettle();
  }

  testWidgets('Empty_TakeAPhoto', (tester) async {
    await pumpInvoiceScreen(tester, const ScanCaptureScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    expect(find.text(l10n().scanCaptureEmptyTitle), findsOneWidget);
    expect(find.text(l10n().scanCaptureTakePhoto), findsOneWidget);
    expect(find.text(l10n().scanCaptureFromGallery), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Loading_WhileTheCameraIsOpen', (tester) async {
    photo(Completer<Result<CapturedImage?, Failure>>().future);
    await pumpInvoiceScreen(tester, const ScanCaptureScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n().scanCaptureTakePhoto));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_CameraDenied_Retry', (tester) async {
    photo(
      Future.value(const Err(LocalFailure(LocalFailureReason.cameraDenied))),
    );
    await pumpInvoiceScreen(tester, const ScanCaptureScreen(), mocks: mocks);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n().scanCaptureTakePhoto));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorLocalCameraDenied), findsOneWidget);
    expect(find.text(l10n().commonRetry), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_PreviewWithUseAndRetake', (tester) async {
    await openPreview(tester);

    expect(find.text(l10n().scanCaptureUsePhoto), findsOneWidget);
    expect(find.text(l10n().scanCaptureRetake), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('UsePhoto_Uploaded_OpensTheInvoice', (tester) async {
    queued();
    when(() => mocks.queue.uploadNow(clientRequestId))
        .thenAnswer((_) async => const ScanUploadOutcome.created(invoiceId));
    await openPreview(tester);

    await tester.tap(find.text(l10n().scanCaptureUsePhoto));
    await tester.pumpAndSettle();

    expect(navigatedTo(RouteNames.invoiceDetail), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('UsePhoto_Waits_SavedForLaterAndQueue', (tester) async {
    queued();
    when(() => mocks.queue.uploadNow(clientRequestId)).thenAnswer(
      (_) async =>
          const ScanUploadOutcome.waiting(PendingScanStatus.waitingRetry),
    );
    await openPreview(tester);

    await tester.tap(find.text(l10n().scanCaptureUsePhoto));
    await tester.pumpAndSettle();

    expect(navigatedTo(RouteNames.scanQueue), findsOneWidget);
    expect(find.text(l10n().scanCaptureSavedForLater), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('UsePhoto_Saving_ThenQueueFullBanner', (tester) async {
    final saving = Completer<Result<PendingScan, Failure>>();
    when(
      () => mocks.queue.enqueue(
        any(),
        shopId: any(named: 'shopId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) => saving.future);
    await openPreview(tester);

    await tester.tap(find.text(l10n().scanCaptureUsePhoto));
    await tester.pump();
    expect(find.text(l10n().scanCaptureSaving), findsWidgets);

    saving.complete(const Err(LocalFailure(LocalFailureReason.queueFull)));
    await tester.pumpAndSettle();
    expect(find.text(l10n().errorLocalQueueFull), findsOneWidget);
    expect(find.text(l10n().scanCaptureUsePhoto), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Dark_Preview', (tester) async {
    photo(Future.value(const Ok(CapturedImage(path: 'missing.jpg'))));
    await pumpInvoiceScreen(
      tester,
      const ScanCaptureScreen(),
      mocks: mocks,
      themeMode: ThemeMode.dark,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n().scanCaptureTakePhoto));
    await tester.pumpAndSettle();

    expect(find.text(l10n().scanCaptureUsePhoto), findsOneWidget);
  }, variant: localeVariant);
}
