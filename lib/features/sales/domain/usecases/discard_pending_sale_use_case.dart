import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

/// Drops a sale whose outcome is unknown without sending it again.
final class DiscardPendingSaleUseCase {
  const new(this._repository);

  final SalesRepository _repository;

  Future<void> call(String clientRequestId) =>
      _repository.discardPending(clientRequestId);
}
