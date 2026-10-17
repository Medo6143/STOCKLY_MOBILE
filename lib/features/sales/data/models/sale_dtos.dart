import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/decimal_json_converters.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';

part 'sale_dtos.freezed.dart';
part 'sale_dtos.g.dart';

/// Contract S1 request line. `unitPrice` is `null` unless overridden.
@freezed
abstract class CreateSaleItemRequestDto with _$CreateSaleItemRequestDto {
  const factory({
    required String productId,
    required String productUnitId,
    @QuantityConverter() required Quantity quantity,
    @NullableMoneyConverter() required Money? unitPrice,
  }) = _CreateSaleItemRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$CreateSaleItemRequestDtoFromJson(json);
}

/// Contract S1 request body.
@freezed
abstract class CreateSaleRequestDto with _$CreateSaleRequestDto {
  const factory({
    required String clientRequestId,
    required String? note,
    required List<CreateSaleItemRequestDto> items,
  }) = _CreateSaleRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$CreateSaleRequestDtoFromJson(json);
}

/// Contract `SaleItemDto`.
@freezed
abstract class SaleItemDto with _$SaleItemDto {
  const factory({
    required String id,
    required String productId,
    required String productName,
    required String productUnitId,
    required String unitName,
    @QuantityConverter() required Quantity quantity,
    @MoneyConverter() required Money listUnitPrice,
    @MoneyConverter() required Money unitPrice,
    required bool priceOverridden,
    @MoneyConverter() required Money lineTotal,
    @QuantityConverter() required Quantity balanceAfter,
  }) = _SaleItemDto;

  factory fromJson(Map<String, Object?> json) => _$SaleItemDtoFromJson(json);
}

/// Contract `SaleDto.warnings[]`. [code] stays the wire string; the mapper
/// rejects codes the contract does not list.
@freezed
abstract class SaleWarningDto with _$SaleWarningDto {
  const factory({required String code, required String productId}) =
      _SaleWarningDto;

  factory fromJson(Map<String, Object?> json) => _$SaleWarningDtoFromJson(json);
}

/// Contract `SaleDto`.
@freezed
abstract class SaleDto with _$SaleDto {
  const factory({
    required String id,
    required String clientRequestId,
    @MoneyConverter() required Money totalAmount,
    required String? note,
    required bool priceOverridden,
    required List<SaleItemDto> items,
    required DateTime createdAt,
    required String createdByUserId,
    required List<SaleWarningDto> warnings,
  }) = _SaleDto;

  factory fromJson(Map<String, Object?> json) => _$SaleDtoFromJson(json);
}

/// Contract `SaleListItem`.
@freezed
abstract class SaleListItemDto with _$SaleListItemDto {
  const factory({
    required String id,
    @MoneyConverter() required Money totalAmount,
    required int itemCount,
    required DateTime createdAt,
  }) = _SaleListItemDto;

  factory fromJson(Map<String, Object?> json) =>
      _$SaleListItemDtoFromJson(json);
}
