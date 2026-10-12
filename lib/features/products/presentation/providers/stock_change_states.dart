import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/products/domain/entities/stock_count_result.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/presentation/providers/product_form_errors.dart';

part 'stock_change_states.freezed.dart';

/// The stock adjustment form (design §11): loading while [isSubmitting],
/// errors under fields or in the banner, and the new [movement] once
/// recorded.
@freezed
abstract class StockAdjustmentState with _$StockAdjustmentState {
  const factory({
    @Default(false) bool isSubmitting,
    @Default(ProductFormErrors()) ProductFormErrors errors,
    StockMovement? movement,
  }) = _StockAdjustmentState;
}

/// The stock count form (design §11): loading while [isSubmitting], errors
/// under fields or in the banner, and the [result] once recorded.
@freezed
abstract class StockCountState with _$StockCountState {
  const factory({
    @Default(false) bool isSubmitting,
    @Default(ProductFormErrors()) ProductFormErrors errors,
    StockCountResult? result,
  }) = _StockCountState;
}
