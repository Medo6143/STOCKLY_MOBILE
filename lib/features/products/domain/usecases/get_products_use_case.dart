import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_paging.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P1: one page of the product list ([ProductPaging.pageSize] rows).
final class GetProductsUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<Paged<ProductListItem>, Failure>> call(
    ProductQuery query, {
    required int page,
  }) => _repository.getProducts(
    query,
    page: page,
    pageSize: ProductPaging.pageSize,
  );
}
