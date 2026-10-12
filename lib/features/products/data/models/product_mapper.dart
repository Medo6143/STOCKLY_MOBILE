import 'package:stockly/features/products/data/models/product_dtos.dart';
import 'package:stockly/features/products/data/models/product_request_dtos.dart';
import 'package:stockly/features/products/domain/entities/product_base_unit.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_lookup.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_count_result.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';

/// Contract enum strings of `StockMovementDto.reason`.
abstract final class ProductWire {
  static const Map<String, StockMovementReason> reasons = {
    'InvoiceReceipt': StockMovementReason.invoiceReceipt,
    'Sale': StockMovementReason.sale,
    'ManualAdjustment': StockMovementReason.manualAdjustment,
    'StockCount': StockMovementReason.stockCount,
    'InvoiceReversal': StockMovementReason.invoiceReversal,
  };
}

extension ProductListItemDtoMapper on ProductListItemDto {
  ProductListItem toEntity() => ProductListItem(
    id: id,
    name: name,
    quantity: quantity,
    baseUnit: ProductBaseUnit(
      id: baseUnit.id,
      name: baseUnit.name,
      sellPrice: baseUnit.sellPrice,
    ),
    lowStockThreshold: lowStockThreshold,
    isLowStock: isLowStock,
    isArchived: isArchived,
  );
}

extension UnitDtoMapper on UnitDto {
  ProductUnit toEntity() => ProductUnit(
    id: id,
    name: name,
    factor: factor,
    sellPrice: sellPrice,
    barcode: barcode,
    isBase: isBase,
  );
}

extension ProductDetailDtoMapper on ProductDetailDto {
  /// Throws [FormatException] when the units have no base unit.
  ProductDetail toEntity() {
    if (!units.any((u) => u.isBase)) {
      throw const FormatException('ProductDetail without a base unit');
    }
    return ProductDetail(
      id: id,
      name: name,
      barcode: barcode,
      category: category,
      quantity: quantity,
      costPrice: costPrice,
      lowStockThreshold: lowStockThreshold,
      isLowStock: isLowStock,
      isArchived: isArchived,
      units: [for (final unit in units) unit.toEntity()],
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension StockMovementDtoMapper on StockMovementDto {
  /// Throws [FormatException] for a reason the contract does not list.
  StockMovement toEntity() => StockMovement(
    id: id,
    productId: productId,
    quantityChange: quantityChange,
    balanceAfter: balanceAfter,
    reason:
        ProductWire.reasons[reason] ??
        (throw FormatException('Unknown movement reason', reason)),
    invoiceId: invoiceId,
    saleId: saleId,
    note: note,
    createdByUserId: createdByUserId,
    createdAt: createdAt,
  );
}

extension StockCountResponseDtoMapper on StockCountResponseDto {
  StockCountResult toEntity() => StockCountResult(
    changed: changed,
    quantity: quantity,
    movement: movement?.toEntity(),
  );
}

extension ProductLookupResponseDtoMapper on ProductLookupResponseDto {
  ProductLookup toEntity() =>
      ProductLookup(product: product.toEntity(), unit: unit.toEntity());
}

extension ProductDraftMapper on ProductDraft {
  CreateProductRequestDto toRequest() => CreateProductRequestDto(
    name: name,
    barcode: barcode,
    category: category,
    baseUnitName: baseUnitName,
    costPrice: costPrice,
    baseUnitSellPrice: baseUnitSellPrice,
    lowStockThreshold: lowStockThreshold,
    openingQuantity: openingQuantity,
  );
}

extension ProductUpdateMapper on ProductUpdate {
  UpdateProductRequestDto toRequest() => UpdateProductRequestDto(
    name: name,
    barcode: barcode,
    category: category,
    costPrice: costPrice,
    lowStockThreshold: lowStockThreshold,
  );
}

extension UnitDraftMapper on UnitDraft {
  UnitRequestDto toRequest() => UnitRequestDto(
    name: name,
    factor: factor,
    sellPrice: sellPrice,
    barcode: barcode,
  );
}

extension StockAdjustmentDraftMapper on StockAdjustmentDraft {
  AdjustmentRequestDto toRequest() => AdjustmentRequestDto(
    quantityChange: quantityChange,
    unitId: unitId,
    note: note,
  );
}

extension StockCountDraftMapper on StockCountDraft {
  StockCountRequestDto toRequest() =>
      StockCountRequestDto(countedQuantity: countedQuantity, unitId: unitId);
}
