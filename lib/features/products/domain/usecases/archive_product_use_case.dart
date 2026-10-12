import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P5 (Owner): archives a product. Idempotent.
final class ArchiveProductUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<void, Failure>> call(String productId) =>
      _repository.archiveProduct(productId);
}
