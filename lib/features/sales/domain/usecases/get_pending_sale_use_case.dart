import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

/// The shop's sale whose outcome is unknown, to reopen it locked (design
/// §6.8).
final class GetPendingSaleUseCase {
  const new(this._repository);

  final SalesRepository _repository;

  Future<PendingSale?> call(String shopId) => _repository.pendingSale(shopId);
}
