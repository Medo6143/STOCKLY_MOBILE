import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';

part 'stock_count_result.freezed.dart';

/// The outcome of a stock count (contract P10). When the count matched,
/// [changed] is `false` and there is no [movement].
@freezed
abstract class StockCountResult with _$StockCountResult {
  const factory({
    required bool changed,
    required Quantity quantity,
    required StockMovement? movement,
  }) = _StockCountResult;
}
