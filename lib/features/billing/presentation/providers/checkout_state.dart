import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/wallet_phone_rules.dart';

part 'checkout_state.freezed.dart';

/// The checkout sheet (plans-payments brief): the chosen method, the
/// wallet phone's errors, the last request sent (its `clientRequestId` is
/// reused while the user retries the same attempt), the failure in the
/// banner, and the started [payment].
@freezed
abstract class CheckoutState with _$CheckoutState {
  const factory({
    @Default(PaymentMethod.card) PaymentMethod method,

    /// The phone failed the device-side rule.
    WalletPhoneIssue? phoneIssue,

    /// The server's `walletPhone` messages (`Validation.Failed`).
    @Default(<String>[]) List<String> phoneMessages,
    @Default(false) bool isSubmitting,

    /// The last submit failure, shown in the banner.
    Failure? failure,

    /// The request of the current attempt.
    CheckoutRequest? lastRequest,

    /// `Billing.PaymentPending`: the shop's pending payment to open.
    String? pendingPaymentId,

    /// The payment that started; the sheet closes on it.
    Payment? payment,
  }) = _CheckoutState;
}

extension CheckoutStateX on CheckoutState {
  bool get needsWalletPhone => method == PaymentMethod.wallet;
}
