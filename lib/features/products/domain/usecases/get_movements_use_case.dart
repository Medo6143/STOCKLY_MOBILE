import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/products/domain/entities/product_paging.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P11: one page of a product's stock history, newest first.
final class GetMovementsUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<Paged<StockMovement>, Failure>> call(
    String productId, {
    required int page,
  }) => _repository.getMovements(
    productId,
    page: page,
    pageSize: ProductPaging.pageSize,
  );
}
