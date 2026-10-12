import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P3: creates a product; the Owner may set the opening stock.
final class CreateProductUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<ProductDetail, Failure>> call(ProductDraft draft) =>
      _repository.createProduct(draft);
}
