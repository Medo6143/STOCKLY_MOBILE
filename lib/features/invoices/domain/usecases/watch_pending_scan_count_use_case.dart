import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';

/// How many scans of a shop have not uploaded, on every change.
final class WatchPendingScanCountUseCase {
  const new(this._repository);

  final ScanQueueRepository _repository;

  Stream<int> call(String shopId) => _repository.watchPendingCount(shopId);
}
