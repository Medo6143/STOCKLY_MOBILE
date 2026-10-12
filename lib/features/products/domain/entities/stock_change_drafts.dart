import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/quantity.dart';

part 'stock_change_drafts.freezed.dart';

/// A manual stock correction (contract P9) in [unitId] (the base unit when
/// `null`). [quantityChange] is signed and never zero.
@freezed
abstract class StockAdjustmentDraft with _$StockAdjustmentDraft {
  const factory({
    required Quantity quantityChange,
    required String? unitId,
    required String note,
  }) = _StockAdjustmentDraft;
}

/// A counted quantity (contract P10) in [unitId] (the base unit when
/// `null`).
@freezed
abstract class StockCountDraft with _$StockCountDraft {
  const factory({required Quantity countedQuantity, required String? unitId}) =
      _StockCountDraft;
}
