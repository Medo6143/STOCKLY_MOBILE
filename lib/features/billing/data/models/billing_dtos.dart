import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/decimal_json_converters.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/calendar_date_converters.dart';

part 'billing_dtos.freezed.dart';
part 'billing_dtos.g.dart';

/// Contract §12.1 `BillingPlan`.
@freezed
abstract class BillingPlanDto with _$BillingPlanDto {
  const factory({
    required String id,
    required String code,
    required String name,
    @MoneyConverter() required Money monthlyPrice,
    required int dailyScanQuota,
    required int maxMembers,
    required bool isFree,
    required bool isCurrent,
  }) = _BillingPlanDto;

  factory fromJson(Map<String, Object?> json) => _$BillingPlanDtoFromJson(json);
}

/// Contract §12.1 `PaymentDto`. [method] and [status] stay wire strings;
/// the mapper rejects values the contract does not list.
@freezed
abstract class PaymentDto with _$PaymentDto {
  const factory({
    required String id,
    required String clientRequestId,
    required String planId,
    required String planName,
    @MoneyConverter() required Money amount,
    required String currency,
    required String method,
    required String status,
    required String? checkoutUrl,
    required String? referenceNumber,
    required DateTime? expiresAt,
    required String? failureReason,
    required DateTime createdAt,
    required DateTime? paidAt,
  }) = _PaymentDto;

  factory fromJson(Map<String, Object?> json) => _$PaymentDtoFromJson(json);
}

/// Contract §12.1 `SubscriptionSummary`.
@freezed
abstract class SubscriptionSummaryDto with _$SubscriptionSummaryDto {
  const factory({
    required BillingPlanDto plan,
    @CalendarDateConverter() required CalendarDate startsOn,
    @NullableCalendarDateConverter() required CalendarDate? endsOn,
    required int effectiveDailyScanQuota,
    required int scansToday,
    required int memberCount,
    required PaymentDto? pendingPayment,
  }) = _SubscriptionSummaryDto;

  factory fromJson(Map<String, Object?> json) =>
      _$SubscriptionSummaryDtoFromJson(json);
}

/// Contract B3 request body. `walletPhone` is `null` unless the method is
/// `Wallet`; the client never sends an amount.
@freezed
abstract class CheckoutRequestDto with _$CheckoutRequestDto {
  const factory({
    required String clientRequestId,
    required String planId,
    required String method,
    required String? walletPhone,
  }) = _CheckoutRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$CheckoutRequestDtoFromJson(json);
}
