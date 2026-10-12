import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';

part 'product_detail.freezed.dart';

/// One product with its units (contract `ProductDetail`). [units] has the
/// base unit first, then the others by factor ascending.
@freezed
abstract class ProductDetail with _$ProductDetail {
  const factory({
    required String id,
    required String name,
    required String? barcode,
    required String? category,
    required Quantity quantity,
    required Money costPrice,
    required Quantity lowStockThreshold,
    required bool isLowStock,
    required bool isArchived,
    required List<ProductUnit> units,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ProductDetail;
}

extension ProductDetailX on ProductDetail {
  /// The base unit (the contract always includes it).
  ProductUnit get baseUnit => units.firstWhere((u) => u.isBase);

  /// The unit with [unitId], or `null`.
  ProductUnit? unitById(String unitId) {
    for (final unit in units) {
      if (unit.id == unitId) {
        return unit;
      }
    }
    return null;
  }
}
