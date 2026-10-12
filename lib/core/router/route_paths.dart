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

  static const String settings = '/settings';

  /// Home in Sprint 3 (no dashboard yet); `/dashboard` from Sprint 4.
  static const String home = products;

  /// Query parameter of `/splash` with the location to resume.
  static const String fromParameter = 'from';

  /// Path parameters (design §3.1).
  static const String productIdParameter = 'productId';
  static const String unitIdParameter = 'unitId';
  static const String invoiceIdParameter = 'invoiceId';
  static const String saleIdParameter = 'saleId';

  /// Query parameters of `/products`: `lowStock=true`, `archived=true`.
  static const String lowStockParameter = 'lowStock';
  static const String archivedParameter = 'archived';
  static const String trueValue = 'true';

  /// `/products/<productId>`.
  static String productDetailOf(String productId) => '$products/$productId';
}
