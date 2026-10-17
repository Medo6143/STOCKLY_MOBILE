import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/decimal_json_converters.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/calendar_date_converters.dart';

part 'invoice_dtos.freezed.dart';
part 'invoice_dtos.g.dart';

/// Contract `newProduct` (I4 request and `InvoiceItemDto`).
@freezed
abstract class NewProductDto with _$NewProductDto {
  const factory({
    required String name,
    required String baseUnitName,
    @MoneyConverter() required Money sellPrice,
  }) = _NewProductDto;

  factory fromJson(Map<String, Object?> json) => _$NewProductDtoFromJson(json);
}

/// Contract `InvoiceListItem`. Enum values stay wire strings; the mapper
/// rejects values the contract does not list.
@freezed
abstract class InvoiceListItemDto with _$InvoiceListItemDto {
  const factory({
    required String id,
    required String status,
    required String? supplierName,
    required String? invoiceNumber,
    @NullableCalendarDateConverter() required CalendarDate? invoiceDate,
    @NullableMoneyConverter() required Money? totalAmount,
    required int itemCount,
    required List<String> warnings,
    required DateTime createdAt,
  }) = _InvoiceListItemDto;

  factory fromJson(Map<String, Object?> json) =>
      _$InvoiceListItemDtoFromJson(json);
}

/// Contract `InvoiceItemDto`.
@freezed
abstract class InvoiceItemDto with _$InvoiceItemDto {
  const factory({
    required String id,
    required int lineNo,
    required String rawName,
    required String? productId,
    required String? productName,
    required String? productUnitId,
    required String? unitName,
    @QuantityConverter() required Quantity quantity,
    @MoneyConverter() required Money unitPrice,
    @MoneyConverter() required Money lineTotal,
    @NullableCalendarDateConverter() required CalendarDate? expiryDate,
    required String? batchNo,
    @NullableMatchConfidenceConverter()
    required MatchConfidence? matchConfidence,
    required NewProductDto? newProduct,
  }) = _InvoiceItemDto;

  factory fromJson(Map<String, Object?> json) => _$InvoiceItemDtoFromJson(json);
}

/// Contract `InvoiceDetail`.
@freezed
abstract class InvoiceDetailDto with _$InvoiceDetailDto {
  const factory({
    required String id,
    required String clientRequestId,
    required String status,
    required String? supplierId,
    required String? supplierName,
    required String? invoiceNumber,
    @NullableCalendarDateConverter() required CalendarDate? invoiceDate,
    @NullableMoneyConverter() required Money? totalAmount,
    @NullableMoneyConverter() required Money? computedTotal,
    required List<String> warnings,
    required String? failureReason,
    required List<InvoiceItemDto> items,
    required DateTime createdAt,
    required DateTime? processedAt,
    required DateTime? confirmedAt,
  }) = _InvoiceDetailDto;

  factory fromJson(Map<String, Object?> json) =>
      _$InvoiceDetailDtoFromJson(json);
}

/// Contract I4 request line. Exactly one of [productId] + [productUnitId]
/// or [newProduct] is set; `lineTotal` is never sent.
@freezed
abstract class UpdateInvoiceItemRequestDto with _$UpdateInvoiceItemRequestDto {
  const factory({
    required int lineNo,
    required String rawName,
    required String? productId,
    required String? productUnitId,
    required NewProductDto? newProduct,
    @QuantityConverter() required Quantity quantity,
    @MoneyConverter() required Money unitPrice,
    @NullableCalendarDateConverter() required CalendarDate? expiryDate,
    required String? batchNo,
  }) = _UpdateInvoiceItemRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$UpdateInvoiceItemRequestDtoFromJson(json);
}

/// Contract I4 request body.
@freezed
abstract class UpdateInvoiceItemsRequestDto
    with _$UpdateInvoiceItemsRequestDto {
  const factory({
    required String? supplierName,
    required String? invoiceNumber,
    @NullableCalendarDateConverter() required CalendarDate? invoiceDate,
    @NullableMoneyConverter() required Money? totalAmount,
    required List<UpdateInvoiceItemRequestDto> items,
  }) = _UpdateInvoiceItemsRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$UpdateInvoiceItemsRequestDtoFromJson(json);
}
