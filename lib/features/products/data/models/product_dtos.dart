import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/decimal_json_converters.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

part 'product_dtos.freezed.dart';
part 'product_dtos.g.dart';

/// Contract `ProductListItem.baseUnit`.
@freezed
abstract class ProductBaseUnitDto with _$ProductBaseUnitDto {
  const factory({
    required String id,
    required String name,
    @MoneyConverter() required Money sellPrice,
  }) = _ProductBaseUnitDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ProductBaseUnitDtoFromJson(json);
}

/// Contract `ProductListItem`.
@freezed
abstract class ProductListItemDto with _$ProductListItemDto {
  const factory({
    required String id,
    required String name,
    @QuantityConverter() required Quantity quantity,
    required ProductBaseUnitDto baseUnit,
    @QuantityConverter() required Quantity lowStockThreshold,
    required bool isLowStock,
    required bool isArchived,
  }) = _ProductListItemDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ProductListItemDtoFromJson(json);
}

/// Contract `UnitDto`.
@freezed
abstract class UnitDto with _$UnitDto {
  const factory({
    required String id,
    required String name,
    @UnitFactorConverter() required UnitFactor factor,
    @MoneyConverter() required Money sellPrice,
    required String? barcode,
    required bool isBase,
  }) = _UnitDto;

  factory fromJson(Map<String, Object?> json) => _$UnitDtoFromJson(json);
}

/// Contract `ProductDetail`.
@freezed
abstract class ProductDetailDto with _$ProductDetailDto {
  const factory({
    required String id,
    required String name,
    required String? barcode,
    required String? category,
    @QuantityConverter() required Quantity quantity,
    @MoneyConverter() required Money costPrice,
    @QuantityConverter() required Quantity lowStockThreshold,
    required bool isLowStock,
    required bool isArchived,
    required List<UnitDto> units,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ProductDetailDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ProductDetailDtoFromJson(json);
}

/// Contract `StockMovementDto`. [reason] stays the wire string; the mapper
/// rejects values the contract does not list.
@freezed
abstract class StockMovementDto with _$StockMovementDto {
  const factory({
    required String id,
    required String productId,
    @QuantityConverter() required Quantity quantityChange,
    @QuantityConverter() required Quantity balanceAfter,
    required String reason,
    required String? invoiceId,
    required String? saleId,
    required String? note,
    required String createdByUserId,
    required DateTime createdAt,
  }) = _StockMovementDto;

  factory fromJson(Map<String, Object?> json) =>
      _$StockMovementDtoFromJson(json);
}

/// Contract P10 response.
@freezed
abstract class StockCountResponseDto with _$StockCountResponseDto {
  const factory({
    required bool changed,
    @QuantityConverter() required Quantity quantity,
    required StockMovementDto? movement,
  }) = _StockCountResponseDto;

  factory fromJson(Map<String, Object?> json) =>
      _$StockCountResponseDtoFromJson(json);
}

/// Contract P12 response.
@freezed
abstract class ProductLookupResponseDto with _$ProductLookupResponseDto {
  const factory({required ProductListItemDto product, required UnitDto unit}) =
      _ProductLookupResponseDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ProductLookupResponseDtoFromJson(json);
}
