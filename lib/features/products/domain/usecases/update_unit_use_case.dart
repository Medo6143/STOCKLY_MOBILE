import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P7: changes a unit; the base unit keeps factor 1.
final class UpdateUnitUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<ProductUnit, Failure>> call(
    String productId,
    String unitId,
    UnitDraft draft,
  ) => _repository.updateUnit(productId, unitId, draft);
}
