import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';

/// Compresses the photo and queues it with a new `clientRequestId`
/// (design §6.1). Capture is never blocked by the daily quota.
final class CaptureInvoiceUseCase {
  const new(this._repository);

  final ScanQueueRepository _repository;

  Future<Result<PendingScan, Failure>> call(
    CapturedImage image, {
    required String shopId,
    required String userId,
  }) => _repository.enqueue(image, shopId: shopId, userId: userId);
}
