import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';

part 'product_draft.freezed.dart';

/// A new product (contract P3). [openingQuantity] is Owner-only and is
/// recorded by the server as an opening stock count.
@freezed
abstract class ProductDraft with _$ProductDraft {
  const factory({
    required String name,
    required String? barcode,
    required String? category,
    required String baseUnitName,
    required Money costPrice,
    required Money baseUnitSellPrice,
    required Quantity? lowStockThreshold,
    required Quantity? openingQuantity,
  }) = _ProductDraft;
}

/// The editable details of a product (contract P4). The base unit's name
/// and price change through the unit endpoints.
@freezed
abstract class ProductUpdate with _$ProductUpdate {
  const factory({
    required String name,
    required String? barcode,
    required String? category,
    required Money costPrice,
    required Quantity lowStockThreshold,
  }) = _ProductUpdate;
}
