import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';

/// The queued scans of a shop, newest first, on every change.
final class WatchPendingScansUseCase {
  const new(this._repository);

  final ScanQueueRepository _repository;

  Stream<List<PendingScan>> call(String shopId) =>
      _repository.watchPending(shopId);
}
