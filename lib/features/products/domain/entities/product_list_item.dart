import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/features/products/domain/entities/product_base_unit.dart';

part 'product_list_item.freezed.dart';

/// One row of the product list (contract `ProductListItem`). [quantity] is
/// in the base unit and may be negative.
@freezed
abstract class ProductListItem with _$ProductListItem {
  const factory({
    required String id,
    required String name,
    required Quantity quantity,
    required ProductBaseUnit baseUnit,
    required Quantity lowStockThreshold,
    required bool isLowStock,
    required bool isArchived,
  }) = _ProductListItem;
}
