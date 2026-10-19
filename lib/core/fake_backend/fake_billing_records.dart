import 'package:decimal/decimal.dart';

/// Contract §12.1 `PaymentMethod` values.
abstract final class FakePaymentMethods {
  static const String card = 'Card';
  static const String wallet = 'Wallet';
  static const String kiosk = 'Kiosk';
  static const Set<String> all = {card, wallet, kiosk};
}

/// Contract §12.1 `PaymentStatus` values.
abstract final class FakePaymentStatuses {
  static const String pending = 'Pending';
  static const String paid = 'Paid';
  static const String failed = 'Failed';
  static const String expired = 'Expired';
}

/// A plan of the fake platform (contract `BillingPlan`), named in both
/// languages because B1 answers in the request language.
final class FakePlan {
  new({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.monthlyPrice,
    required this.dailyScanQuota,
    required this.maxMembers,
    this.active = true,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final Decimal monthlyPrice;
  final int dailyScanQuota;
  final int maxMembers;
  bool active;

  bool get isFree => monthlyPrice == Decimal.zero;

  String nameIn(String language) => language == 'en' ? nameEn : nameAr;
}

/// The plan a shop is on. Days are Cairo calendar days, `yyyy-MM-dd`.
final class FakeSubscription {
  new({
    required this.shopId,
    required this.planId,
    required this.startsOn,
    required this.endsOn,
  });

  final String shopId;
  String planId;
  String startsOn;

  /// `null` for an open-ended (free) plan.
  String? endsOn;
}

/// A payment of a fake shop (contract `PaymentDto`). Only the debug panel
/// (standing in for the provider callback) and expiry change [status].
final class FakePayment {
  new({
    required this.id,
    required this.shopId,
    required this.clientRequestId,
    required this.planId,
    required this.amount,
    required this.method,
    required this.checkoutUrl,
    required this.referenceNumber,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String shopId;
  final String clientRequestId;
  final String planId;
  final Decimal amount;
  final String method;
  final String? checkoutUrl;
  final String? referenceNumber;
  final DateTime expiresAt;
  final DateTime createdAt;
  String status = FakePaymentStatuses.pending;
  String? failureReason;
  DateTime? paidAt;

  bool get isPending => status == FakePaymentStatuses.pending;
}
