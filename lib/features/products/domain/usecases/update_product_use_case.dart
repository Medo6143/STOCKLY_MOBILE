import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P4: changes the product details.
final class UpdateProductUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<ProductDetail, Failure>> call(
    String productId,
    ProductUpdate update,
  ) => _repository.updateProduct(productId, update);
}
