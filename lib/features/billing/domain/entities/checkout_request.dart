import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';

part 'checkout_request.freezed.dart';

/// Contract B3 request. [clientRequestId] is created once per attempt and
/// sent again on every retry of that attempt (rule 20, ADR-0006).
/// [walletPhone] is set for [PaymentMethod.wallet] only, normalized.
@freezed
abstract class CheckoutRequest with _$CheckoutRequest {
  const factory({
    required String clientRequestId,
    required String planId,
    required PaymentMethod method,
    required String? walletPhone,
  }) = _CheckoutRequest;
}

extension CheckoutRequestX on CheckoutRequest {
  /// The same request apart from the id: a retry of this attempt.
  bool sameAttemptAs({
    required String planId,
    required PaymentMethod method,
    required String? walletPhone,
  }) =>
      this.planId == planId &&
      this.method == method &&
      this.walletPhone == walletPhone;
}
