import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/decimal_json_converters.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/calendar_date_converters.dart';

part 'dashboard_dtos.freezed.dart';
part 'dashboard_dtos.g.dart';

/// Contract D1 `todaySales`.
@freezed
abstract class TodaySalesDto with _$TodaySalesDto {
  const factory({
    required int count,
    @MoneyConverter() required Money total,
    required int overriddenSalesCount,
  }) = _TodaySalesDto;

  factory fromJson(Map<String, Object?> json) => _$TodaySalesDtoFromJson(json);
}

/// Contract D1 response.
@freezed
abstract class DashboardSummaryDto with _$DashboardSummaryDto {
  const factory({
    required int productCount,
    required int lowStockCount,
    required int negativeStockCount,
    required int expiringSoonCount,
    required TodaySalesDto todaySales,
    required int invoicesAwaitingReview,
    required DateTime generatedAt,
  }) = _DashboardSummaryDto;

  factory fromJson(Map<String, Object?> json) =>
      _$DashboardSummaryDtoFromJson(json);
}

/// Contract D2 `ExpiringItem`.
@freezed
abstract class ExpiringItemDto with _$ExpiringItemDto {
  const factory({
    required String productId,
    required String productName,
    @CalendarDateConverter() required CalendarDate expiryDate,
    required String? batchNo,
    required String invoiceId,
    @QuantityConverter() required Quantity lineQuantity,
    @QuantityConverter() required Quantity currentQuantity,
  }) = _ExpiringItemDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ExpiringItemDtoFromJson(json);
}
