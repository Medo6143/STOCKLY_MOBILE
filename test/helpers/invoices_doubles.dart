import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/offline/background_sync.dart';
import 'package:stockly/core/offline/scan_sync_scheduler.dart';
import 'package:stockly/core/platform/connectivity.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_warning.dart';
import 'package:stockly/features/invoices/domain/entities/new_product.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';
import 'package:stockly/features/invoices/domain/repositories/invoice_photo_source.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';
import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';

class MockInvoicesRepository extends Mock implements InvoicesRepository;

class MockScanQueueRepository extends Mock implements ScanQueueRepository;

class MockInvoicePhotoSource extends Mock implements InvoicePhotoSource;

class MockBackgroundSyncRegistrar extends Mock
    implements BackgroundSyncRegistrar;

const String invoiceId = '0192f0a0-6c1e-7b3a-9d2e-e00000000001';
const String clientRequestId = '0192f0a0-6c1e-7b3a-9d2e-f00000000001';
const String productId = '0192f0a0-6c1e-7b3a-9d2e-a00000000001';
const String baseUnitId = '0192f0a0-6c1e-7b3a-9d2e-b00000000002';
const String boxUnitId = '0192f0a0-6c1e-7b3a-9d2e-b00000000003';

Money money(String raw) => Money.fromApi(raw);
Quantity quantity(String raw) => Quantity.fromApi(raw);

/// An invoice line; [matched] links it to the product's box.
InvoiceItem invoiceItem({
  int lineNo = 1,
  String rawName = 'بنادول اكسترا ٢٠ قرص',
  bool matched = true,
  NewProduct? newProduct,
  String qty = '10.000',
  String price = '36.00',
  String total = '360.00',
}) => InvoiceItem(
  id: '0192f0a0-6c1e-7b3a-9d2e-e1000000000$lineNo',
  lineNo: lineNo,
  rawName: rawName,
  productId: matched ? productId : null,
  productName: matched ? 'بنادول اكسترا' : null,
  productUnitId: matched ? boxUnitId : null,
  unitName: matched ? 'علبة' : null,
  quantity: quantity(qty),
  unitPrice: money(price),
  lineTotal: money(total),
  expiryDate: matched ? const CalendarDate(2027, 3, 31) : null,
  batchNo: matched ? 'B12' : null,
  matchConfidence: matched ? MatchConfidence.fromApi('0.95') : null,
  newProduct: newProduct,
);

final NewProduct sitalNew = NewProduct(
  name: 'سيتال شراب',
  baseUnitName: 'زجاجة',
  sellPrice: money('25.00'),
);

/// An invoice in [status] with [items] (default: one matched line, one
/// unresolved line and one new product).
InvoiceDetail invoiceDetail({
  InvoiceStatus status = InvoiceStatus.needsReview,
  List<InvoiceItem>? items,
  List<InvoiceWarning> warnings = const [InvoiceWarning.totalMismatch],
  String? failureReason,
  String? total = '1250.00',
}) => InvoiceDetail(
  id: invoiceId,
  clientRequestId: clientRequestId,
  status: status,
  supplierId: null,
  supplierName: 'شركة الأدوية المتحدة',
  invoiceNumber: 'INV-1043',
  invoiceDate: const CalendarDate(2026, 10, 10),
  totalAmount: total == null ? null : money(total),
  computedTotal: money('583.00'),
  warnings: warnings,
  failureReason: failureReason,
  items:
      items ??
      [
        invoiceItem(),
        invoiceItem(
          lineNo: 2,
          rawName: 'مرهم جلد ٣٠ جم',
          matched: false,
          qty: '5.000',
          price: '22.50',
          total: '112.50',
        ),
        invoiceItem(
          lineNo: 3,
          rawName: 'سيتال شراب ١٠٠ مل',
          matched: false,
          newProduct: sitalNew,
          qty: '6.000',
          price: '18.50',
          total: '111.00',
        ),
      ],
  createdAt: DateTime.utc(2026, 10, 12, 7),
  processedAt: DateTime.utc(2026, 10, 12, 7),
  confirmedAt: status == InvoiceStatus.confirmed
      ? DateTime.utc(2026, 10, 13, 7)
      : null,
);

InvoiceListItem invoiceListItem({
  String id = invoiceId,
  InvoiceStatus status = InvoiceStatus.needsReview,
  String? supplierName = 'شركة الأدوية المتحدة',
  List<InvoiceWarning> warnings = const [InvoiceWarning.totalMismatch],
}) => InvoiceListItem(
  id: id,
  status: status,
  supplierName: supplierName,
  invoiceNumber: 'INV-1043',
  invoiceDate: const CalendarDate(2026, 10, 10),
  totalAmount: money('1250.00'),
  itemCount: 3,
  warnings: warnings,
  createdAt: DateTime.utc(2026, 10, 12, 7),
);

PendingScan pendingScan({
  String id = clientRequestId,
  PendingScanStatus status = PendingScanStatus.queued,
  DateTime? nextAttemptAt,
  String? lastErrorCode,
  int attemptCount = 0,
}) => PendingScan(
  clientRequestId: id,
  status: status,
  imagePath: 'missing/$id.jpg',
  imageSizeBytes: 1024,
  attemptCount: attemptCount,
  nextAttemptAt: nextAttemptAt,
  lastErrorCode: lastErrorCode,
  capturedAt: DateTime.utc(2026, 10, 12, 7),
);

ApiProblemInfo problem(int status) =>
    ApiProblemInfo(status: status, traceId: '00-trace-00');

const NotFoundFailure invoiceNotFound = NotFoundFailure(
  ApiErrorCode.invoiceNotFound,
  ApiProblemInfo(status: HttpStatus.notFound),
);

const ConflictFailure notEditable = ConflictFailure(
  ApiErrorCode.invoiceNotEditable,
  ApiProblemInfo(status: HttpStatus.conflict),
);

/// Registers mocktail fallbacks once per test file.
void registerInvoiceFallbacks() {
  registerFallbackValue(const CapturedImage(path: 'x'));
  registerFallbackValue(
    const InvoiceDraft(header: InvoiceHeaderDraft(), lines: []),
  );
}

/// A network state the test sets.
final class FakeConnectivityMonitor implements ConnectivityMonitor {
  new({bool online = true}) {
    _controller.add(online);
  }

  final StreamController<bool> _controller = StreamController<bool>();

  void set({required bool online}) => _controller.add(online);

  @override
  Stream<bool> watchOnline() => _controller.stream;

  Future<void> close() => _controller.close();
}

/// A background registrar that only counts.
final class CountingSyncRegistrar implements BackgroundSyncRegistrar {
  int uploads = 0;
  int periodic = 0;

  @override
  Future<void> requestUpload() async => uploads++;

  @override
  Future<void> registerPeriodic() async => periodic++;
}

/// A queue with nothing in it, for app-level tests that do not exercise
/// scans.
final class EmptyScanQueue implements ScanQueueRepository {
  @override
  Stream<List<PendingScan>> watchPending(String shopId) =>
      Stream.value(const []);

  @override
  Stream<int> watchPendingCount(String shopId) => Stream.value(0);

  @override
  Future<Result<PendingScan, Failure>> enqueue(
    CapturedImage image, {
    required String shopId,
    required String userId,
  }) async => const Err(LocalFailure(LocalFailureReason.storage));

  @override
  Future<ScanUploadOutcome> uploadNow(String clientRequestId) async =>
      const ScanUploadOutcome.notQueued();

  @override
  Future<DateTime?> runQueue({required bool force}) async => null;

  @override
  Future<Result<void, Failure>> delete(String clientRequestId) async =>
      const Ok(null);
}

/// A scheduler that never uploads and never starts a timer.
ScanSyncScheduler idleScheduler(Clock clock) => ScanSyncScheduler(
  connectivity: _AlwaysOnline(),
  background: CountingSyncRegistrar(),
  sync: ({required force}) async => null,
  clock: clock,
);

final class _AlwaysOnline implements ConnectivityMonitor {
  @override
  Stream<bool> watchOnline() => Stream.value(true);
}

/// Overrides that keep the scan queue out of tests that do not exercise it
/// (no database, no platform channels, no timers).
List<Override> quietScanQueueOverrides({ScanQueueRepository? queue}) => [
  scanQueueRepositoryProvider.overrideWithValue(queue ?? EmptyScanQueue()),
  scanSyncSchedulerProvider.overrideWith(
    (ref) => idleScheduler(const SystemClock()),
  ),
  connectivityMonitorProvider.overrideWithValue(_AlwaysOnline()),
];
