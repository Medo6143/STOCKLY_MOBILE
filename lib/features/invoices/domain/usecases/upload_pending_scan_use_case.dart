import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';
import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';

/// One upload attempt of a queued scan, with its stored `clientRequestId`.
final class UploadPendingScanUseCase {
  const new(this._repository);

  final ScanQueueRepository _repository;

  Future<ScanUploadOutcome> call(String clientRequestId) =>
      _repository.uploadNow(clientRequestId);
}
