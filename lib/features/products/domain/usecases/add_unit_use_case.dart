import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P6: adds a unit to a product.
final class AddUnitUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<ProductUnit, Failure>> call(
    String productId,
    UnitDraft draft,
  ) => _repository.addUnit(productId, draft);
}
