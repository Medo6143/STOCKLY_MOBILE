import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_detail_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_line_editor_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_line_editor_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_list_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_processing_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_processing_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/invoices/presentation/providers/product_picker_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_capture_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_capture_state.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_queue_notifier.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/products_doubles.dart' as products;

void main() {
  late MockInvoicesRepository invoices;
  late MockScanQueueRepository queue;
  late MockInvoicePhotoSource photos;
  late products.MockProductsRepository catalog;
  late StreamController<int> count;

  setUpAll(() {
    registerInvoiceFallbacks();
    products.registerProductFallbacks();
  });

  setUp(() {
    invoices = MockInvoicesRepository();
    queue = MockScanQueueRepository();
    photos = MockInvoicePhotoSource();
    catalog = products.MockProductsRepository();
    count = StreamController<int>.broadcast();
    when(() => queue.watchPendingCount(any())).thenAnswer((_) => count.stream);
    when(() => invoices.getInvoice(invoiceId))
        .thenAnswer((_) async => Ok(invoiceDetail()));
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        invoicesRepositoryProvider.overrideWithValue(invoices),
        scanQueueRepositoryProvider.overrideWithValue(queue),
        invoicePhotoSourceProvider.overrideWithValue(photos),
        productsRepositoryProvider.overrideWithValue(catalog),
        currentSessionProvider.overrideWithValue(ownerSession),
        appLoggerProvider.overrideWithValue(const NoopLogger()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('InvoiceListNotifier', () {
    void answerPage(List<InvoiceListItem> items) =>
        when(
          () => invoices.getInvoices(
            status: any(named: 'status'),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).thenAnswer(
          (_) async => Ok(
            Paged(
              items: items,
              page: 1,
              pageSize: 20,
              totalCount: items.length,
            ),
          ),
        );

    test('FirstPage_WithTheStatusFilter', () async {
      answerPage([invoiceListItem()]);
      final c = container();

      final page = await c.read(
        invoiceListProvider(InvoiceStatus.needsReview).future,
      );

      expect(page.items, [invoiceListItem()]);
      verify(
        () => invoices.getInvoices(
          status: InvoiceStatus.needsReview,
          page: 1,
          pageSize: 20,
        ),
      ).called(1);
    });

    test('Error_IsTheFailure', () async {
      when(
        () => invoices.getInvoices(
          status: any(named: 'status'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final c = container();

      await expectLater(
        c.read(invoiceListProvider(null).future),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('AScanLeavesTheQueue_ListReloads', () async {
      answerPage([invoiceListItem()]);
      final c = container();
      final sub = c.listen(invoiceListProvider(null), (_, _) {});
      c.listen(pendingScanCountProvider, (_, _) {});
      await c.read(invoiceListProvider(null).future);
      count.add(2);
      await Future<void>.delayed(Duration.zero);
      count.add(1);
      await Future<void>.delayed(Duration.zero);
      await c.read(invoiceListProvider(null).future);

      verify(() => invoices.getInvoices(status: null, page: 1, pageSize: 20))
          .called(2);
      sub.close();
    });
  });

  test('InvoiceDetailNotifier_NotFound', () async {
    when(() => invoices.getInvoice(invoiceId))
        .thenAnswer((_) async => const Err(invoiceNotFound));
    final c = container();

    await expectLater(
      c.read(invoiceDetailProvider(invoiceId).future),
      throwsA(invoiceNotFound),
    );
  });

  group('InvoiceProcessingNotifier', () {
    testWidgets('Finished_StateAndDetailReloads', (tester) async {
      var calls = 0;
      when(() => invoices.getInvoice(invoiceId)).thenAnswer((_) async {
        calls++;
        return Ok(
          calls < 3
              ? invoiceDetail(status: InvoiceStatus.processing)
              : invoiceDetail(),
        );
      });
      final c = container()
        ..listen(invoiceProcessingProvider(invoiceId), (_, _) {});
      await tester.pump();
      expect(
        c.read(invoiceProcessingProvider(invoiceId)).phase,
        InvoiceProcessingPhase.polling,
      );

      await tester.pump(const Duration(seconds: 4));

      final state = c.read(invoiceProcessingProvider(invoiceId));
      expect(state.phase, InvoiceProcessingPhase.finished);
      expect(state.invoice?.status, InvoiceStatus.needsReview);
    });

    testWidgets('After60sStillProcessing_StillProcessing_RestartPolls', (
      tester,
    ) async {
      var calls = 0;
      when(() => invoices.getInvoice(invoiceId)).thenAnswer((_) async {
        calls++;
        return Ok(invoiceDetail(status: InvoiceStatus.processing));
      });
      final c = container()
        ..listen(invoiceProcessingProvider(invoiceId), (_, _) {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));

      expect(
        c.read(invoiceProcessingProvider(invoiceId)).phase,
        InvoiceProcessingPhase.stillProcessing,
      );
      expect(calls, 31);

      c.read(invoiceProcessingProvider(invoiceId).notifier).restart();
      c.read(invoiceProcessingProvider(invoiceId));
      await tester.pump();
      expect(calls, 32);
      expect(
        c.read(invoiceProcessingProvider(invoiceId)).phase,
        InvoiceProcessingPhase.polling,
      );
      c.dispose();
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 32);
    });

    testWidgets('LastPollFailed_FailedWithTheFailure', (tester) async {
      when(() => invoices.getInvoice(invoiceId))
          .thenAnswer((_) async => const Err(NetworkFailure()));
      final c = container()
        ..listen(invoiceProcessingProvider(invoiceId), (_, _) {});
      await tester.pump();
      expect(
        c.read(invoiceProcessingProvider(invoiceId)).phase,
        InvoiceProcessingPhase.polling,
      );

      await tester.pump(const Duration(seconds: 60));

      final state = c.read(invoiceProcessingProvider(invoiceId));
      expect(state.phase, InvoiceProcessingPhase.failed);
      expect(state.failure, const NetworkFailure());
    });
  });

  group('InvoiceReviewNotifier', () {
    Future<(ProviderContainer, InvoiceReviewNotifier)> review() async {
      final c = container()
        ..listen(invoiceReviewProvider(invoiceId), (_, _) {});
      await c.read(invoiceReviewProvider(invoiceId).future);
      return (c, c.read(invoiceReviewProvider(invoiceId).notifier));
    }

    InvoiceReviewState stateOf(ProviderContainer c) =>
        c.read(invoiceReviewProvider(invoiceId)).requireValue;

    InvoiceLineDraft resolved(InvoiceLineDraft line) => line.copyWith(
      choice: const LineProductChoice.existing(
        productId: productId,
        productUnitId: baseUnitId,
        productName: 'بنادول اكسترا',
        unitName: 'شريط',
      ),
    );

    test('Build_DraftFromTheInvoice', () async {
      final (c, _) = await review();

      final state = stateOf(c);
      expect(state.draft, InvoiceDraft.fromDetail(invoiceDetail()));
      expect(state.isDirty, isFalse);
      expect(state.isReadOnly, isFalse);
      expect(state.canSave, isTrue);
    });

    test('HeaderEdits_MakeItDirty', () async {
      final (c, notifier) = await review();

      notifier
        ..setSupplierName('  مورد  ')
        ..setInvoiceNumber('')
        ..setInvoiceDate(const CalendarDate(2026, 10, 11))
        ..setTotalAmount('99.5');

      final header = stateOf(c).draft.header;
      expect(header.supplierName, 'مورد');
      expect(header.invoiceNumber, isNull);
      expect(header.invoiceDate, const CalendarDate(2026, 10, 11));
      expect(header.totalAmount, money('99.50'));
      expect(stateOf(c).isDirty, isTrue);
    });

    test('BadTotal_IssueAndCannotSave', () async {
      final (c, notifier) = await review();

      notifier.setTotalAmount('1.234');

      expect(stateOf(c).totalAmountIssue, InvoiceFieldIssue.tooManyDecimals);
      expect(stateOf(c).canSave, isFalse);
      notifier.setTotalAmount('');
      expect(stateOf(c).draft.header.totalAmount, isNull);
      expect(stateOf(c).canSave, isTrue);
    });

    test('AddAndRemoveLine', () async {
      final (c, notifier) = await review();
      final draft = stateOf(c).draft;

      notifier.putLine(draft.lines.first.copyWith(lineNo: draft.nextLineNo));
      expect(stateOf(c).draft.lines.map((l) => l.lineNo), [1, 2, 3, 4]);
      notifier.removeLine(2);
      expect(stateOf(c).draft.lines.map((l) => l.lineNo), [1, 3, 4]);
    });

    test('UnresolvedLine_FlaggedAndNothingSent', () async {
      final (c, notifier) = await review();

      await notifier.save();

      expect(stateOf(c).lineErrors, {2});
      verifyNever(() => invoices.saveItems(any(), any()));
    });

    test('Save_SendsAllLines_ServerAnswerReplacesTheDraft', () async {
      final (c, notifier) = await review();
      final line = stateOf(c).draft.lineByNo(2)!;
      notifier.putLine(resolved(line));
      final saved = invoiceDetail(items: [invoiceItem()], warnings: const []);
      when(() => invoices.saveItems(any(), any()))
          .thenAnswer((_) async => Ok(saved));

      await notifier.save();

      final sent =
          verify(() => invoices.saveItems(invoiceId, captureAny()))
                  .captured
                  .single
              as InvoiceDraft;
      expect(sent.lines, hasLength(3));
      expect(stateOf(c).draft, InvoiceDraft.fromDetail(saved));
      expect(stateOf(c).isDirty, isFalse);
      expect(stateOf(c).savedCount, 1);
    });

    test('ValidationFailed_MessagesOnTheirLines', () async {
      final (c, notifier) = await review();
      notifier.putLine(resolved(stateOf(c).draft.lineByNo(2)!));
      when(() => invoices.saveItems(any(), any())).thenAnswer(
        (_) async => Err(
          ValidationFailure(
            ApiErrorCode.validationFailed,
            problem(HttpStatus.badRequest),
            fieldErrors: const {
              'items[2].quantity': ['bad quantity'],
              'supplierName': ['too long'],
            },
          ),
        ),
      );

      await notifier.save();

      expect(stateOf(c).lineMessages, {
        3: ['bad quantity'],
      });
      expect(stateOf(c).failure, isA<ValidationFailure>());
      expect(stateOf(c).isSaving, isFalse);
    });

    test('ServerLineProductRequired_HighlightsUnresolved', () async {
      final (c, notifier) = await review();
      notifier.putLine(resolved(stateOf(c).draft.lineByNo(2)!));
      when(() => invoices.saveItems(any(), any())).thenAnswer(
        (_) async => Err(
          InvalidInputFailure(
            ApiErrorCode.invoiceUnitNotOfProduct,
            problem(HttpStatus.badRequest),
          ),
        ),
      );

      await notifier.save();

      expect(
        (stateOf(c).failure! as ApiFailure).code,
        ApiErrorCode.invoiceUnitNotOfProduct,
      );
    });

    test('NotEditable_ReloadsReadOnly', () async {
      final (c, notifier) = await review();
      notifier.putLine(resolved(stateOf(c).draft.lineByNo(2)!));
      when(() => invoices.saveItems(any(), any()))
          .thenAnswer((_) async => const Err(notEditable));
      when(() => invoices.getInvoice(invoiceId)).thenAnswer(
        (_) async => Ok(invoiceDetail(status: InvoiceStatus.confirmed)),
      );

      await notifier.save();

      expect(stateOf(c).isReadOnly, isTrue);
      expect(stateOf(c).failure, notEditable);
      notifier.setSupplierName('x');
      expect(stateOf(c).isDirty, isFalse);
    });
  });

  group('InvoiceLineEditorNotifier', () {
    Future<ProviderContainer> editorFor(int lineNo) async {
      final c = container()
        ..listen(invoiceReviewProvider(invoiceId), (_, _) {});
      await c.read(invoiceReviewProvider(invoiceId).future);
      c.listen(
        invoiceLineEditorProvider((invoiceId: invoiceId, lineNo: lineNo)),
        (_, _) {},
      );
      return c;
    }

    void answerProduct() =>
        when(() => catalog.getProduct(any()))
            .thenAnswer((_) async => Ok(products.detail()));

    test('ExistingLine_LoadsTheUnitsOfItsProduct', () async {
      answerProduct();
      final c = await editorFor(1);
      const key = (invoiceId: invoiceId, lineNo: 1);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(invoiceLineEditorProvider(key));
      expect(state.mode, LineProductMode.existing);
      expect(state.unitId, boxUnitId);
      expect(state.units?.map((u) => u.id), [baseUnitId, boxUnitId]);
    });

    test('ChooseProduct_BaseUnitFirst_ThenSaveIntoTheDraft', () async {
      answerProduct();
      final c = await editorFor(2);
      const key = (invoiceId: invoiceId, lineNo: 2);
      final notifier = c.read(invoiceLineEditorProvider(key).notifier)
        ..chooseProduct(productId: productId, name: 'بنادول اكسترا');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(invoiceLineEditorProvider(key)).unitId, baseUnitId);
      notifier
        ..chooseUnit(boxUnitId)
        ..save(
          rawName: 'مرهم',
          quantity: '5',
          unitPrice: '22.50',
          batchNo: '',
          expiryDate: null,
          newProductName: '',
          newProductBaseUnitName: '',
          newProductSellPrice: '',
        );

      expect(c.read(invoiceLineEditorProvider(key)).done, isTrue);
      final line = c
          .read(invoiceReviewProvider(invoiceId))
          .requireValue
          .draft
          .lineByNo(2)!;
      expect(
        line.choice,
        const LineProductChoice.existing(
          productId: productId,
          productUnitId: boxUnitId,
          productName: 'بنادول اكسترا',
          unitName: 'علبة',
        ),
      );
    });

    test('NewLineAsNewProduct_Appended', () async {
      final c = await editorFor(4);
      const key = (invoiceId: invoiceId, lineNo: 4);
      c.read(invoiceLineEditorProvider(key).notifier)
        ..chooseNewProduct()
        ..save(
          rawName: 'سيتال',
          quantity: '6',
          unitPrice: '18.5',
          batchNo: '',
          expiryDate: null,
          newProductName: 'سيتال شراب',
          newProductBaseUnitName: 'زجاجة',
          newProductSellPrice: '25',
        );

      final lines = c
          .read(invoiceReviewProvider(invoiceId))
          .requireValue
          .draft
          .lines;
      expect(lines.map((l) => l.lineNo), [1, 2, 3, 4]);
      expect(lines.last.choice, LineProductChoice.newProduct(sitalNew));
    });

    test('Invalid_IssuesAndDraftUntouched', () async {
      final c = await editorFor(2);
      const key = (invoiceId: invoiceId, lineNo: 2);

      c
          .read(invoiceLineEditorProvider(key).notifier)
          .save(
            rawName: '',
            quantity: '0',
            unitPrice: '',
            batchNo: '',
            expiryDate: null,
            newProductName: '',
            newProductBaseUnitName: '',
            newProductSellPrice: '',
          );

      final state = c.read(invoiceLineEditorProvider(key));
      expect(state.done, isFalse);
      expect(
        state.issues.keys,
        containsAll([
          InvoiceLineField.rawName,
          InvoiceLineField.quantity,
          InvoiceLineField.unitPrice,
          InvoiceLineField.product,
        ]),
      );
    });

    test('UnitsFail_FailureThenRetry', () async {
      when(() => catalog.getProduct(any()))
          .thenAnswer((_) async => const Err(NetworkFailure()));
      final c = await editorFor(1);
      const key = (invoiceId: invoiceId, lineNo: 1);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        c.read(invoiceLineEditorProvider(key)).unitsFailure,
        const NetworkFailure(),
      );

      answerProduct();
      c.read(invoiceLineEditorProvider(key).notifier).retryUnits();
      await Future<void>.delayed(Duration.zero);

      expect(c.read(invoiceLineEditorProvider(key)).units, isNotNull);
    });
  });

  group('ScanCaptureNotifier', () {
    void answerPhoto(Result<CapturedImage?, Failure> result) =>
        when(() => photos.takePhoto()).thenAnswer((_) async => result);

    void answerQueue() => when(
      () => queue.enqueue(
        any(),
        shopId: any(named: 'shopId'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async => Ok(pendingScan()));

    test('Photo_Preview', () async {
      answerPhoto(const Ok(CapturedImage(path: 'p.jpg')));
      final c = container()..listen(scanCaptureProvider, (_, _) {});

      await c.read(scanCaptureProvider.notifier).takePhoto();

      expect(
        c.read(scanCaptureProvider),
        const ScanCaptureState(
          phase: ScanCapturePhase.preview,
          imagePath: 'p.jpg',
        ),
      );
    });

    test('Cancelled_StaysIdle', () async {
      answerPhoto(const Ok(null));
      final c = container()..listen(scanCaptureProvider, (_, _) {});

      await c.read(scanCaptureProvider.notifier).takePhoto();

      expect(c.read(scanCaptureProvider), const ScanCaptureState());
    });

    test('CameraDenied_Failure', () async {
      answerPhoto(const Err(LocalFailure(LocalFailureReason.cameraDenied)));
      final c = container()..listen(scanCaptureProvider, (_, _) {});

      await c.read(scanCaptureProvider.notifier).takePhoto();

      expect(
        c.read(scanCaptureProvider).failure,
        const LocalFailure(LocalFailureReason.cameraDenied),
      );
      expect(c.read(scanCaptureProvider).phase, ScanCapturePhase.idle);
    });

    test('UsePhoto_QueuesForTheSessionShop_ThenUploaded', () async {
      answerPhoto(const Ok(CapturedImage(path: 'p.jpg')));
      answerQueue();
      when(() => queue.uploadNow(clientRequestId))
          .thenAnswer((_) async => const ScanUploadOutcome.created(invoiceId));
      final c = container()..listen(scanCaptureProvider, (_, _) {});
      final notifier = c.read(scanCaptureProvider.notifier);
      await notifier.takePhoto();

      await notifier.usePhoto();

      expect(c.read(scanCaptureProvider).phase, ScanCapturePhase.uploaded);
      expect(c.read(scanCaptureProvider).invoiceId, invoiceId);
      verify(
        () => queue.enqueue(
          const CapturedImage(path: 'p.jpg'),
          shopId: ownerSession.shop.id,
          userId: ownerSession.user.id,
        ),
      ).called(1);
    });

    test('UploadWaits_Queued', () async {
      answerPhoto(const Ok(CapturedImage(path: 'p.jpg')));
      answerQueue();
      when(() => queue.uploadNow(clientRequestId)).thenAnswer(
        (_) async =>
            const ScanUploadOutcome.waiting(PendingScanStatus.waitingRetry),
      );
      final c = container()..listen(scanCaptureProvider, (_, _) {});
      final notifier = c.read(scanCaptureProvider.notifier);
      await notifier.takePhoto();

      await notifier.usePhoto();

      expect(c.read(scanCaptureProvider).phase, ScanCapturePhase.queued);
    });

    testWidgets('SlowUpload_QueuedAfter10s', (tester) async {
      answerPhoto(const Ok(CapturedImage(path: 'p.jpg')));
      answerQueue();
      when(() => queue.uploadNow(clientRequestId))
          .thenAnswer((_) => Completer<ScanUploadOutcome>().future);
      final c = container()..listen(scanCaptureProvider, (_, _) {});
      final notifier = c.read(scanCaptureProvider.notifier);
      await notifier.takePhoto();

      unawaited(notifier.usePhoto());
      await tester.pump();
      expect(c.read(scanCaptureProvider).phase, ScanCapturePhase.uploading);
      await tester.pump(const Duration(seconds: 10));

      expect(c.read(scanCaptureProvider).phase, ScanCapturePhase.queued);
    });

    test('QueueFull_BackToPreviewWithFailure', () async {
      answerPhoto(const Ok(CapturedImage(path: 'p.jpg')));
      when(
        () => queue.enqueue(
          any(),
          shopId: any(named: 'shopId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer(
        (_) async => const Err(LocalFailure(LocalFailureReason.queueFull)),
      );
      final c = container()..listen(scanCaptureProvider, (_, _) {});
      final notifier = c.read(scanCaptureProvider.notifier);
      await notifier.takePhoto();

      await notifier.usePhoto();

      expect(c.read(scanCaptureProvider).phase, ScanCapturePhase.preview);
      expect(
        c.read(scanCaptureProvider).failure,
        const LocalFailure(LocalFailureReason.queueFull),
      );
      verifyNever(() => queue.uploadNow(any()));
    });
  });

  group('ScanQueueNotifier', () {
    test('RetryNow_ForcedRun', () async {
      when(() => queue.runQueue(force: true)).thenAnswer((_) async => null);
      final c = container()..listen(scanQueueProvider, (_, _) {});

      await c.read(scanQueueProvider.notifier).retryNow();

      verify(() => queue.runQueue(force: true)).called(1);
      expect(c.read(scanQueueProvider).isRetrying, isFalse);
    });

    test('Delete_OkOrFailure', () async {
      when(() => queue.delete('a')).thenAnswer((_) async => const Ok(null));
      when(() => queue.delete('b')).thenAnswer(
        (_) async => const Err(LocalFailure(LocalFailureReason.storage)),
      );
      final c = container()..listen(scanQueueProvider, (_, _) {});
      final notifier = c.read(scanQueueProvider.notifier);

      expect(await notifier.delete('a'), isTrue);
      expect(await notifier.delete('b'), isFalse);
      expect(c.read(scanQueueProvider).failure, isA<LocalFailure>());
    });
  });

  test('PendingProviders_ScopedToTheSessionShop', () async {
    when(() => queue.watchPending(ownerSession.shop.id))
        .thenAnswer((_) => Stream.value([pendingScan()]));
    final c = container()..listen(pendingScansProvider, (_, _) {});

    expect(await c.read(pendingScansProvider.future), [pendingScan()]);
  });

  test('NoSession_EmptyQueue', () async {
    final c = ProviderContainer(
      overrides: [
        scanQueueRepositoryProvider.overrideWithValue(queue),
        currentSessionProvider.overrideWithValue(null),
      ],
    );
    addTearDown(c.dispose);
    c
      ..listen(pendingScanCountProvider, (_, _) {})
      ..listen(pendingScansProvider, (_, _) {});

    expect(await c.read(pendingScanCountProvider.future), 0);
    expect(await c.read(pendingScansProvider.future), isEmpty);
    verifyNever(() => queue.watchPending(any()));
  });

  test('ProductPicker_FirstPageOfTheSearch', () async {
    when(
      () => catalog.getProducts(
        any(),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Ok(products.page([products.listItem()])));
    final c = container()..listen(productPickerProvider('بنادول'), (_, _) {});

    final items = await c.read(productPickerProvider('بنادول').future);

    expect(items, [products.listItem()]);
    verify(
      () => catalog.getProducts(
        const ProductQuery(search: 'بنادول'),
        page: 1,
        pageSize: 20,
      ),
    ).called(1);
  });
}
