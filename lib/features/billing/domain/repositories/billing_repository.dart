import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';

/// Contract B1–B6 (§12, ADR-0015). The shop always comes from the access
/// token. The app never sees provider keys and never sends an amount.
abstract interface class BillingRepository {
  /// B1: active plans, free first, then by price.
  Future<Result<List<BillingPlan>, Failure>> getPlans();

  /// B2.
  Future<Result<SubscriptionSummary, Failure>> getSubscription();

  /// B3 (Owner). A repeat of the same `clientRequestId` returns the
  /// existing payment.
  Future<Result<Payment, Failure>> checkout(CheckoutRequest request);

  /// B4.
  Future<Result<Payment, Failure>> getPayment(String paymentId);

  /// B5, newest first.
  Future<Result<Paged<Payment>, Failure>> getPayments({
    required int page,
    required int pageSize,
  });

  /// B6 (Owner): a `Pending` payment becomes `Expired`.
  Future<Result<Payment, Failure>> cancelPayment(String paymentId);
}
