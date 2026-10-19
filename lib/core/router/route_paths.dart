/// Route paths (design §3.1).
abstract final class RoutePaths {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String suspended = '/suspended';

  static const String dashboard = '/dashboard';
  static const String expiringSoon = '/dashboard/expiring-soon';

  static const String products = '/products';
  static const String productCreate = '/products/new';
  static const String productDetail = '/products/:productId';
  static const String productEdit = '/products/:productId/edit';
  static const String unitCreate = '/products/:productId/units/new';
  static const String unitEdit = '/products/:productId/units/:unitId/edit';
  static const String stockAdjust = '/products/:productId/adjust';
  static const String stockCount = '/products/:productId/count';
  static const String movements = '/products/:productId/movements';

  static const String invoices = '/invoices';
  static const String scanCapture = '/invoices/scan';
  static const String scanQueue = '/invoices/queue';
  static const String invoiceDetail = '/invoices/:invoiceId';
  static const String invoiceReview = '/invoices/:invoiceId/review';
  static const String invoiceLineEdit =
      '/invoices/:invoiceId/review/lines/:lineNo';

  static const String sales = '/sales';
  static const String quickSale = '/sales/new';
  static const String saleDetail = '/sales/:saleId';

  static const String profile = '/profile';
  static const String settings = '/profile/settings';
  static const String plans = '/profile/plans';
  static const String paymentHistory = '/profile/payments';
  static const String paymentStatus = '/profile/payments/:paymentId';

  /// The privacy policy: open signed in (profile) and signed out
  /// (register), so it sits outside the shell.
  static const String privacyPolicy = '/privacy';

  /// Settings before the profile tab existed; redirects to [settings] so
  /// old links keep working.
  static const String legacySettings = '/settings';

  /// Home after sign-in (design §3.1, Sprint 4).
  static const String home = dashboard;

  /// Query parameter of `/splash` with the location to resume.
  static const String fromParameter = 'from';

  /// Path parameters (design §3.1).
  static const String productIdParameter = 'productId';
  static const String unitIdParameter = 'unitId';
  static const String invoiceIdParameter = 'invoiceId';
  static const String saleIdParameter = 'saleId';
  static const String lineNoParameter = 'lineNo';
  static const String paymentIdParameter = 'paymentId';

  /// Query parameters of `/products`: `lowStock=true`, `archived=true`.
  static const String lowStockParameter = 'lowStock';
  static const String archivedParameter = 'archived';
  static const String trueValue = 'true';

  /// Query parameter of `/invoices`: a contract `InvoiceStatus` name.
  static const String statusParameter = 'status';

  /// The `status` value of the invoices awaiting review (the dashboard
  /// links to them).
  static const String needsReviewValue = 'NeedsReview';

  /// Query parameter of `/sales/:saleId`: `true` when the sale had
  /// already been recorded by an earlier attempt (S1 `200`).
  static const String repeatParameter = 'repeat';

  /// Query parameter of `/dashboard/expiring-soon`: the window in days.
  static const String daysParameter = 'days';

  /// `/products/<productId>`.
  static String productDetailOf(String productId) => '$products/$productId';
}
