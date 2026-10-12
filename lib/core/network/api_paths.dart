/// Endpoint paths exactly as in the contract (base path `/api`).
abstract final class ApiPaths {
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';
  static const String authRefresh = '/api/auth/refresh';
  static const String authLogout = '/api/auth/logout';
  static const String authMe = '/api/auth/me';

  /// Prefix of every auth endpoint; their bodies are never logged.
  static const String authPrefix = '/api/auth/';

  /// P1 (GET) and P3 (POST).
  static const String products = '/api/products';

  /// P12.
  static const String productLookup = '/api/products/lookup';

  /// P2 (GET) and P4 (PUT).
  static String product(String productId) =>
      '$products/${Uri.encodeComponent(productId)}';

  /// P5.
  static String productArchive(String productId) =>
      '${product(productId)}/archive';

  /// P6.
  static String productUnits(String productId) => '${product(productId)}/units';

  /// P7 (PUT) and P8 (DELETE).
  static String productUnit(String productId, String unitId) =>
      '${productUnits(productId)}/${Uri.encodeComponent(unitId)}';

  /// P9.
  static String productAdjustments(String productId) =>
      '${product(productId)}/adjustments';

  /// P10.
  static String productStockCounts(String productId) =>
      '${product(productId)}/stock-counts';

  /// P11.
  static String productMovements(String productId) =>
      '${product(productId)}/movements';
}

/// Query parameter names of the contract (§1.3, P1, P12).
abstract final class ApiQuery {
  static const String page = 'page';
  static const String pageSize = 'pageSize';
  static const String search = 'search';
  static const String lowStock = 'lowStock';
  static const String includeArchived = 'includeArchived';
  static const String barcode = 'barcode';
}
