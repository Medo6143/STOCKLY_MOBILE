import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/payment_status.dart';

part 'payment.freezed.dart';

/// One payment for a plan (contract §12.1 `PaymentDto`). The amount is the
/// plan's price when the checkout started; the app never sends an amount.
@freezed
abstract class Payment with _$Payment {
  const factory({
    required String id,
    required String clientRequestId,
    required String planId,
    required String planName,
    required Money amount,
    required String currency,
    required PaymentMethod method,
    required PaymentStatus status,

    /// Card and wallet: the provider-hosted page to open in the browser.
    required String? checkoutUrl,

    /// Kiosk: the number to pay in cash at a kiosk partner.
    required String? referenceNumber,

    /// After this a `Pending` payment becomes `Expired`.
    required DateTime? expiresAt,

    /// The provider's text, informational only (never switched on).
    required String? failureReason,
    required DateTime createdAt,
    required DateTime? paidAt,
  }) = _Payment;
}

extension PaymentX on Payment {
  bool get isPending => status == PaymentStatus.pending;

  /// The hosted page of a pending card or wallet payment, if any.
  Uri? get openableCheckoutUrl {
    final url = checkoutUrl;
    return isPending && url != null ? Uri.tryParse(url) : null;
  }
}
