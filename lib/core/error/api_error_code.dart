/// Every error `code` of contract §9 the app can receive, plus the `Http.*`
/// framework codes. Clients switch on the code, never on `title`/`detail`.
///
/// Not here on purpose: `Stock.NegativeBalance` (a sale warning, not an error)
/// and the domain movement-rule codes, which always arrive as
/// `500 Server.Unexpected`.
enum ApiErrorCode {
  validationFailed('Validation.Failed'),
  serverUnexpected('Server.Unexpected'),
  httpNotFound('Http.NotFound'),
  httpMethodNotAllowed('Http.MethodNotAllowed'),
  httpUnsupportedMediaType('Http.UnsupportedMediaType'),
  authUnauthenticated('Auth.Unauthenticated'),
  authForbidden('Auth.Forbidden'),
  authEmailTaken('Auth.EmailTaken'),
  authInvalidCredentials('Auth.InvalidCredentials'),
  authNoActiveShop('Auth.NoActiveShop'),
  authInvalidRefreshToken('Auth.InvalidRefreshToken'),
  authRefreshTokenReused('Auth.RefreshTokenReused'),
  authLockedOut('Auth.LockedOut'),
  authTooManyRequests('Auth.TooManyRequests'),
  shopNameRequired('Shop.NameRequired'),
  shopUnknownType('Shop.UnknownType'),
  shopSuspended('Shop.Suspended'),
  productNotFound('Product.NotFound'),
  productNameRequired('Product.NameRequired'),
  productArchived('Product.Archived'),
  productDuplicateBarcode('Product.DuplicateBarcode'),
  productOpeningStockOwnerOnly('Product.OpeningStockOwnerOnly'),
  productUnitNotFound('ProductUnit.NotFound'),
  productUnitNameRequired('ProductUnit.NameRequired'),
  productUnitDuplicateName('ProductUnit.DuplicateName'),
  productUnitDuplicateBarcode('ProductUnit.DuplicateBarcode'),
  productUnitBaseUnitCannotBeRemoved('ProductUnit.BaseUnitCannotBeRemoved'),
  productUnitBaseUnitFactorFixed('ProductUnit.BaseUnitFactorFixed'),
  productUnitInUse('ProductUnit.InUse'),
  precisionTooManyDecimals('Precision.TooManyDecimals'),
  precisionNegative('Precision.Negative'),
  precisionNotPositive('Precision.NotPositive'),
  precisionOutOfRange('Precision.OutOfRange'),
  stockZeroChange('Stock.ZeroChange'),
  stockNoteRequired('Stock.NoteRequired'),
  invoiceNotFound('Invoice.NotFound'),
  invoiceImageRequired('Invoice.ImageRequired'),
  invoiceUnsupportedImageType('Invoice.UnsupportedImageType'),
  invoiceImageTooLarge('Invoice.ImageTooLarge'),
  invoiceNotEditable('Invoice.NotEditable'),
  invoiceNotConfirmable('Invoice.NotConfirmable'),
  invoiceLineProductRequired('Invoice.LineProductRequired'),
  invoiceUnitNotOfProduct('Invoice.UnitNotOfProduct'),
  scanRateLimited('Scan.RateLimited'),
  scanDailyQuotaExceeded('Scan.DailyQuotaExceeded'),
  saleNotFound('Sale.NotFound'),
  saleArchivedProduct('Sale.ArchivedProduct'),
  saleUnitNotOfProduct('Sale.UnitNotOfProduct'),
  planNotFound('Plan.NotFound'),
  planInactive('Plan.Inactive'),
  billingFreePlan('Billing.FreePlan'),
  billingMethodUnavailable('Billing.MethodUnavailable'),
  billingPaymentPending('Billing.PaymentPending'),
  billingNotCancelable('Billing.NotCancelable'),
  billingProviderUnavailable('Billing.ProviderUnavailable'),
  paymentNotFound('Payment.NotFound');

  new(this.wire);

  /// The exact string of the ProblemDetails `code` field.
  final String wire;

  static final Map<String, ApiErrorCode> _byWire = {
    for (final code in values) code.wire: code,
  };

  /// The enum value for a wire code, or `null` for a code the app does not
  /// know (mapped to `UnknownApiFailure`).
  static ApiErrorCode? fromWire(String code) => _byWire[code];
}
