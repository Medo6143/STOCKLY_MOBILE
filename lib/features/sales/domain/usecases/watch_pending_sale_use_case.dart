import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

/// The shop's sale whose outcome is unknown, on every change (the app
/// reopens the quick sale for it, design §6.8).
final class WatchPendingSaleUseCase {
  const new(this._repository);

  final SalesRepository _repository;

  Stream<PendingSale?> call(String shopId) =>
      _repository.watchPendingSale(shopId);
}
