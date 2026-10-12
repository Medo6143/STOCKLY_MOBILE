import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P9 (Owner): a manual correction, recorded as a new movement.
final class AdjustStockUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<StockMovement, Failure>> call(
    String productId,
    StockAdjustmentDraft draft,
  ) => _repository.adjustStock(productId, draft);
}
