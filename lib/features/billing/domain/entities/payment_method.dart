/// How a payment is made (contract §12.1 `PaymentMethod`, ADR-0015).
enum PaymentMethod {
  /// Visa, Mastercard or Meeza on the provider's hosted page.
  card,

  /// Vodafone Cash or another mobile wallet, confirmed on the provider's
  /// hosted page.
  wallet,

  /// Cash at a kiosk partner, with a reference number.
  kiosk,
}

extension PaymentMethodX on PaymentMethod {
  /// Card and wallet are paid on a provider page opened in the browser.
  bool get usesHostedPage => this != PaymentMethod.kiosk;
}
