/// Polling of a pending payment (plans-payments brief).
abstract final class PaymentPolling {
  /// B4 is asked again this often while a payment is `Pending`.
  static const Duration interval = Duration(seconds: 3);

  /// The longest a poll runs when the payment has no `expiresAt`.
  static const Duration windowWithoutExpiry = Duration(minutes: 30);
}

/// Rows per page of the payment history (B5).
abstract final class PaymentPaging {
  static const int pageSize = 20;
}
