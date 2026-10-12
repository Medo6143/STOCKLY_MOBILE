import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_count_result.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P10 (Owner): records a count; a matching count changes nothing.
final class RecordStockCountUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<StockCountResult, Failure>> call(
    String productId,
    StockCountDraft draft,
  ) => _repository.recordStockCount(productId, draft);
}
