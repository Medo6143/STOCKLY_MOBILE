import 'dart:async';
import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/platform/external_browser.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

class MockBillingRepository extends Mock implements BillingRepository;

/// An [ExternalBrowser] that records what it was asked to open.
final class RecordingBrowser implements ExternalBrowser {
  new({this.opens = true});

  /// What the next [open] answers (no browser on the phone when `false`).
  bool opens;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return opens;
  }
}

/// An [ExternalBrowser] that answers only when the test completes [answer]
/// (a browser that takes long to come back).
final class SlowBrowser implements ExternalBrowser {
  final Completer<bool> answer = Completer<bool>();

  @override
  Future<bool> open(Uri uri) => answer.future;
}

const String freePlanId = '0192f0a0-6c1e-7b3a-9d2e-b111ab000001';
const String basicPlanId = '0192f0a0-6c1e-7b3a-9d2e-b111ab000002';
const String proPlanId = '0192f0a0-6c1e-7b3a-9d2e-b111ab000003';
const String paymentId = '0192f0a0-6c1e-7b3a-9d2e-ba1e00000001';
const String paymentRequestId = '0192f0a0-6c1e-7b3a-9d2e-ba1e00000099';
const String checkoutUrl = 'https://fake.stockly.invalid/pay/$paymentId';

BillingPlan billingPlan({
  String id = basicPlanId,
  String name = 'الأساسية',
  String price = '150.00',
  int quota = 150,
  int members = 3,
  bool isCurrent = false,
}) => BillingPlan(
  id: id,
  code: name,
  name: name,
  monthlyPrice: Money.fromApi(price),
  dailyScanQuota: quota,
  maxMembers: members,
  isFree: price == '0.00',
  isCurrent: isCurrent,
);

List<BillingPlan> billingPlans({String currentId = freePlanId}) => [
  billingPlan(
    id: freePlanId,
    name: 'المجانية',
    price: '0.00',
    quota: 50,
    members: 2,
    isCurrent: currentId == freePlanId,
  ),
  billingPlan(isCurrent: currentId == basicPlanId),
  billingPlan(
    id: proPlanId,
    name: 'الاحترافية',
    price: '300.00',
    quota: 500,
    members: 10,
    isCurrent: currentId == proPlanId,
  ),
];

Payment payment({
  String id = paymentId,
  PaymentMethod method = PaymentMethod.card,
  PaymentStatus status = PaymentStatus.pending,
  String? failureReason,
  DateTime? expiresAt,
}) => Payment(
  id: id,
  clientRequestId: paymentRequestId,
  planId: basicPlanId,
  planName: 'الأساسية',
  amount: Money.fromApi('150.00'),
  currency: 'EGP',
  method: method,
  status: status,
  checkoutUrl: method == PaymentMethod.kiosk ? null : checkoutUrl,
  referenceNumber: method == PaymentMethod.kiosk ? '700000001' : null,
  expiresAt: expiresAt ?? DateTime.utc(2026, 10, 12, 8),
  failureReason: failureReason,
  createdAt: DateTime.utc(2026, 10, 12, 7),
  paidAt: status == PaymentStatus.paid
      ? DateTime.utc(2026, 10, 12, 7, 5)
      : null,
);

SubscriptionSummary subscriptionSummary({
  BillingPlan? plan,
  int scansToday = 12,
  int quota = 50,
  int members = 2,
  CalendarDate? endsOn,
  Payment? pendingPayment,
}) => SubscriptionSummary(
  plan: plan ?? billingPlans().first,
  startsOn: const CalendarDate(2026, 10, 1),
  endsOn: endsOn,
  effectiveDailyScanQuota: quota,
  scansToday: scansToday,
  memberCount: members,
  pendingPayment: pendingPayment,
);

ApiProblemInfo billingInfo(int status) => ApiProblemInfo(status: status);

const ConflictFailure paymentPending = ConflictFailure(
  ApiErrorCode.billingPaymentPending,
  ApiProblemInfo(status: HttpStatus.conflict),
);

const ConflictFailure notCancelable = ConflictFailure(
  ApiErrorCode.billingNotCancelable,
  ApiProblemInfo(status: HttpStatus.conflict),
);

const ServerFailure providerUnavailable = ServerFailure(
  ApiErrorCode.billingProviderUnavailable,
  ApiProblemInfo(status: HttpStatus.badGateway),
);

const InvalidInputFailure methodUnavailable = InvalidInputFailure(
  ApiErrorCode.billingMethodUnavailable,
  ApiProblemInfo(status: HttpStatus.badRequest),
);

const NotFoundFailure paymentNotFound = NotFoundFailure(
  ApiErrorCode.paymentNotFound,
  ApiProblemInfo(status: HttpStatus.notFound),
);

const ForbiddenFailure billingForbidden = ForbiddenFailure(
  ApiErrorCode.authForbidden,
  ApiProblemInfo(status: HttpStatus.forbidden),
);

/// Registers mocktail fallbacks once per test file.
void registerBillingFallbacks() {
  registerFallbackValue(
    const CheckoutRequest(
      clientRequestId: paymentRequestId,
      planId: basicPlanId,
      method: PaymentMethod.card,
      walletPhone: null,
    ),
  );
}

/// A billing backend for app-level tests that do not exercise it: the
/// free plan, below the quota, nothing pending.
MockBillingRepository quietBilling() {
  final repository = MockBillingRepository();
  when(repository.getSubscription)
      .thenAnswer((_) async => Ok(subscriptionSummary()));
  when(repository.getPlans).thenAnswer((_) async => Ok(billingPlans()));
  return repository;
}
