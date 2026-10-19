import 'package:stockly/features/billing/data/models/billing_dtos.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';

/// Contract strings of the billing enums (§12.1).
abstract final class BillingWire {
  static const Map<String, PaymentMethod> methods = {
    'Card': PaymentMethod.card,
    'Wallet': PaymentMethod.wallet,
    'Kiosk': PaymentMethod.kiosk,
  };

  static const Map<String, PaymentStatus> statuses = {
    'Pending': PaymentStatus.pending,
    'Paid': PaymentStatus.paid,
    'Failed': PaymentStatus.failed,
    'Expired': PaymentStatus.expired,
  };

  /// Throws [FormatException] for a method the contract does not list.
  static PaymentMethod method(String raw) =>
      methods[raw] ?? (throw FormatException('Unknown payment method', raw));

  /// Throws [FormatException] for a status the contract does not list.
  static PaymentStatus status(String raw) =>
      statuses[raw] ?? (throw FormatException('Unknown payment status', raw));

  /// The wire string of [method].
  static String methodName(PaymentMethod method) =>
      methods.entries.firstWhere((e) => e.value == method).key;
}

extension BillingPlanDtoMapper on BillingPlanDto {
  BillingPlan toEntity() => BillingPlan(
    id: id,
    code: code,
    name: name,
    monthlyPrice: monthlyPrice,
    dailyScanQuota: dailyScanQuota,
    maxMembers: maxMembers,
    isFree: isFree,
    isCurrent: isCurrent,
  );
}

extension PaymentDtoMapper on PaymentDto {
  Payment toEntity() => Payment(
    id: id,
    clientRequestId: clientRequestId,
    planId: planId,
    planName: planName,
    amount: amount,
    currency: currency,
    method: BillingWire.method(method),
    status: BillingWire.status(status),
    checkoutUrl: checkoutUrl,
    referenceNumber: referenceNumber,
    expiresAt: expiresAt,
    failureReason: failureReason,
    createdAt: createdAt,
    paidAt: paidAt,
  );
}

extension SubscriptionSummaryDtoMapper on SubscriptionSummaryDto {
  SubscriptionSummary toEntity() => SubscriptionSummary(
    plan: plan.toEntity(),
    startsOn: startsOn,
    endsOn: endsOn,
    effectiveDailyScanQuota: effectiveDailyScanQuota,
    scansToday: scansToday,
    memberCount: memberCount,
    pendingPayment: pendingPayment?.toEntity(),
  );
}

extension CheckoutRequestMapper on CheckoutRequest {
  CheckoutRequestDto toDto() => CheckoutRequestDto(
    clientRequestId: clientRequestId,
    planId: planId,
    method: BillingWire.methodName(method),
    walletPhone: walletPhone,
  );
}
