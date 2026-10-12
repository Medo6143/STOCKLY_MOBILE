import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/decimal_json_converters.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

part 'product_request_dtos.freezed.dart';
part 'product_request_dtos.g.dart';

/// Contract P3 request body. Decimals are sent as strings; optional values
/// are left out when absent (contract §1.1: absent equals `null`).
@freezed
abstract class CreateProductRequestDto with _$CreateProductRequestDto {
  const factory({
    required String name,
    @JsonKey(includeIfNull: false) required String? barcode,
    @JsonKey(includeIfNull: false) required String? category,
    required String baseUnitName,
    @MoneyConverter() required Money costPrice,
    @MoneyConverter() required Money baseUnitSellPrice,
    @NullableQuantityConverter()
    @JsonKey(includeIfNull: false)
    required Quantity? lowStockThreshold,
    @NullableQuantityConverter()
    @JsonKey(includeIfNull: false)
    required Quantity? openingQuantity,
  }) = _CreateProductRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$CreateProductRequestDtoFromJson(json);
}

/// Contract P4 request body.
@freezed
abstract class UpdateProductRequestDto with _$UpdateProductRequestDto {
  const factory({
    required String name,
    required String? barcode,
    required String? category,
    @MoneyConverter() required Money costPrice,
    @QuantityConverter() required Quantity lowStockThreshold,
  }) = _UpdateProductRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$UpdateProductRequestDtoFromJson(json);
}

/// Contract P6 and P7 request body.
@freezed
abstract class UnitRequestDto with _$UnitRequestDto {
  const factory({
    required String name,
    @UnitFactorConverter() required UnitFactor factor,
    @MoneyConverter() required Money sellPrice,
    required String? barcode,
  }) = _UnitRequestDto;

  factory fromJson(Map<String, Object?> json) => _$UnitRequestDtoFromJson(json);
}

/// Contract P9 request body; a `null` [unitId] means the base unit.
@freezed
abstract class AdjustmentRequestDto with _$AdjustmentRequestDto {
  const factory({
    @QuantityConverter() required Quantity quantityChange,
    required String? unitId,
    required String note,
  }) = _AdjustmentRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$AdjustmentRequestDtoFromJson(json);
}

/// Contract P10 request body; a `null` [unitId] means the base unit.
@freezed
abstract class StockCountRequestDto with _$StockCountRequestDto {
  const factory({
    @QuantityConverter() required Quantity countedQuantity,
    required String? unitId,
  }) = _StockCountRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$StockCountRequestDtoFromJson(json);
}
