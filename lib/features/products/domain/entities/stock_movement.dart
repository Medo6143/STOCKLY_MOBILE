import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';

part 'stock_movement.freezed.dart';

/// One stock change (contract `StockMovementDto`), in the base unit.
/// Movements are append-only: corrections are new movements.
@freezed
abstract class StockMovement with _$StockMovement {
  const factory({
    required String id,
    required String productId,
    required Quantity quantityChange,
    required Quantity balanceAfter,
    required StockMovementReason reason,
    required String? invoiceId,
    required String? saleId,
    required String? note,
    required String createdByUserId,
    required DateTime createdAt,
  }) = _StockMovement;
}
