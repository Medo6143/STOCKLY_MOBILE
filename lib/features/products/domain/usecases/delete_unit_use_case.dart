import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P8: removes a unit that is not the base unit and not in use.
final class DeleteUnitUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<void, Failure>> call(String productId, String unitId) =>
      _repository.deleteUnit(productId, unitId);
}
