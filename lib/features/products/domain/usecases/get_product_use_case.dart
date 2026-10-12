import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P2: one product with its units.
final class GetProductUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<ProductDetail, Failure>> call(String productId) =>
      _repository.getProduct(productId);
}
