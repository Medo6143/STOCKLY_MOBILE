import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_paging.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';
import 'package:stockly/features/invoices/domain/usecases/capture_invoice_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/delete_pending_scan_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/get_invoice_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/get_invoices_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/save_invoice_items_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/sync_pending_scans_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/take_invoice_photo_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/upload_pending_scan_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/watch_invoice_processing_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/watch_pending_scan_count_use_case.dart';
import 'package:stockly/features/invoices/domain/usecases/watch_pending_scans_use_case.dart';

import '../../../helpers/invoices_doubles.dart';

/// One use case each (design §1.4): happy path and the failures it passes
/// on unchanged.
void main() {
  late MockInvoicesRepository invoices;
  late MockScanQueueRepository queue;
  late MockInvoicePhotoSource photos;

  setUpAll(registerInvoiceFallbacks);

  setUp(() {
    invoices = MockInvoicesRepository();
    queue = MockScanQueueRepository();
    photos = MockInvoicePhotoSource();
  });

  test('GetInvoices_PageSize20AndStatus', () async {
    when(
      () => invoices.getInvoices(
        status: any(named: 'status'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer(
      (_) async => Ok(
        Paged<InvoiceListItem>(
          items: [invoiceListItem()],
          page: 2,
          pageSize: 20,
          totalCount: 21,
        ),
      ),
    );

    final result = await GetInvoicesUseCase(invoices)
        .call(InvoiceStatus.failed, page: 2);

    expect(result, isA<Ok<Paged<InvoiceListItem>, Failure>>());
    verify(
      () => invoices.getInvoices(
        status: InvoiceStatus.failed,
        page: 2,
        pageSize: InvoicePaging.pageSize,
      ),
    ).called(1);
  });

  test('GetInvoice_NotFoundPassedOn', () async {
    when(() => invoices.getInvoice(invoiceId))
        .thenAnswer((_) async => const Err(invoiceNotFound));

    final result = await GetInvoiceUseCase(invoices).call(invoiceId);

    expect((result as Err).failure, invoiceNotFound);
  });

  test('SaveItems_ConflictPassedOn', () async {
    final draft = InvoiceDraft.fromDetail(invoiceDetail());
    when(() => invoices.saveItems(invoiceId, draft))
        .thenAnswer((_) async => const Err(notEditable));

    final result = await SaveInvoiceItemsUseCase(invoices)
        .call(invoiceId, draft);

    expect((result as Err).failure, notEditable);
  });

  test('TakePhoto_CameraOrGallery', () async {
    when(() => photos.takePhoto())
        .thenAnswer((_) async => const Ok(CapturedImage(path: 'cam')));
    when(() => photos.pickFromGallery())
        .thenAnswer((_) async => const Ok(null));
    final useCase = TakeInvoicePhotoUseCase(photos);

    expect(
      (await useCase.call(fromGallery: false) as Ok).value,
      const CapturedImage(path: 'cam'),
    );
    expect((await useCase.call(fromGallery: true) as Ok).value, isNull);
  });

  test('Capture_EnqueuesForTheShop', () async {
    when(
      () => queue.enqueue(
        any(),
        shopId: any(named: 'shopId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => Ok(pendingScan()));

    final result = await CaptureInvoiceUseCase(queue).call(
      const CapturedImage(path: 'p'),
      shopId: 's',
      userId: 'u',
    );

    expect((result as Ok).value, pendingScan());
    verify(
      () => queue.enqueue(
        const CapturedImage(path: 'p'),
        shopId: 's',
        userId: 'u',
      ),
    ).called(1);
  });

  test('Upload_Sync_Delete_Watch_Delegate', () async {
    when(() => queue.uploadNow(clientRequestId))
        .thenAnswer((_) async => const ScanUploadOutcome.created(invoiceId));
    when(() => queue.runQueue(force: true))
        .thenAnswer((_) async => DateTime.utc(2026));
    when(() => queue.delete(clientRequestId))
        .thenAnswer((_) async => const Ok(null));
    when(() => queue.watchPending('s'))
        .thenAnswer((_) => Stream.value([pendingScan()]));
    when(() => queue.watchPendingCount('s')).thenAnswer((_) => Stream.value(1));

    expect(
      await UploadPendingScanUseCase(queue).call(clientRequestId),
      const ScanUploadOutcome.created(invoiceId),
    );
    expect(
      await SyncPendingScansUseCase(queue).call(force: true),
      DateTime.utc(2026),
    );
    expect(
      await DeletePendingScanUseCase(queue).call(clientRequestId),
      isA<Ok<void, Failure>>(),
    );
    expect(await WatchPendingScansUseCase(queue).call('s').first, [
      pendingScan(),
    ]);
    expect(await WatchPendingScanCountUseCase(queue).call('s').first, 1);
  });

  group('WatchInvoiceProcessing (polling, contract I3)', () {
    testWidgets('PollsEvery2s_StopsWhenNoLongerProcessing', (tester) async {
      final answers = [
        invoiceDetail(status: InvoiceStatus.processing),
        invoiceDetail(status: InvoiceStatus.processing),
        invoiceDetail(),
      ];
      var calls = 0;
      when(() => invoices.getInvoice(invoiceId))
          .thenAnswer((_) async => Ok(answers[calls++]));
      final polls = <InvoicePoll>[];

      final subscription = WatchInvoiceProcessingUseCase(invoices)
          .call(invoiceId)
          .listen(polls.add);
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 2);
      await tester.pump(const Duration(seconds: 2));

      expect(calls, 3);
      expect(polls.last, InvoicePoll.finished(invoiceDetail()));
      expect(polls.whereType<InvoicePollProcessing>(), hasLength(2));
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 3);
      unawaitedCancel(subscription.cancel());
    });

    testWidgets('StillProcessingAfter60s_TimedOut', (tester) async {
      var calls = 0;
      when(() => invoices.getInvoice(invoiceId)).thenAnswer((_) async {
        calls++;
        return Ok(invoiceDetail(status: InvoiceStatus.processing));
      });
      final polls = <InvoicePoll>[];

      WatchInvoiceProcessingUseCase(invoices).call(invoiceId).listen(polls.add);
      await tester.pump();
      await tester.pump(InvoicePolling.window);

      expect(calls, 31);
      expect(polls.last, const InvoicePoll.timedOut());
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 31);
    });

    testWidgets('FailedPolls_KeepPolling_TimedOutWithTheLastFailure', (
      tester,
    ) async {
      when(() => invoices.getInvoice(invoiceId))
          .thenAnswer((_) async => const Err(invoiceNotFound));
      final polls = <InvoicePoll>[];

      WatchInvoiceProcessingUseCase(invoices).call(invoiceId).listen(polls.add);
      await tester.pump();
      await tester.pump(InvoicePolling.window);

      expect(polls.whereType<InvoicePollFailed>(), hasLength(31));
      expect(
        polls.last,
        const InvoicePoll.timedOut(lastFailure: invoiceNotFound),
      );
    });

    testWidgets('Cancel_StopsTheTimer', (tester) async {
      var calls = 0;
      when(() => invoices.getInvoice(invoiceId)).thenAnswer((_) async {
        calls++;
        return Ok(invoiceDetail(status: InvoiceStatus.processing));
      });

      final subscription = WatchInvoiceProcessingUseCase(invoices)
          .call(invoiceId)
          .listen((_) {});
      await tester.pump();
      unawaitedCancel(subscription.cancel());
      await tester.pump(const Duration(seconds: 10));

      expect(calls, 1);
    });
  });
}

/// Cancels without awaiting: a cancel future may complete outside the
/// test's fake time.
void unawaitedCancel(Future<void> cancel) {}
