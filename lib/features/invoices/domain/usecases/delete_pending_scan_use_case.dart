import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';

/// Removes a queued scan and its photo.
final class DeletePendingScanUseCase {
  const new(this._repository);

  final ScanQueueRepository _repository;

  Future<Result<void, Failure>> call(String clientRequestId) =>
      _repository.delete(clientRequestId);
}
