import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';

/// Uploads the due scans of the signed-in shop. A forced run ("Retry now",
/// the network came back) ignores `nextAttemptAt`. Returns the earliest
/// `nextAttemptAt` left.
final class SyncPendingScansUseCase {
  const new(this._repository);

  final ScanQueueRepository _repository;

  Future<DateTime?> call({required bool force}) =>
      _repository.runQueue(force: force);
}
