/// Endpoint paths exactly as in the contract (base path `/api`).
abstract final class ApiPaths {
  static const String authRegister = '/api/auth/register';
  static const String authLogin = '/api/auth/login';
  static const String authRefresh = '/api/auth/refresh';
  static const String authLogout = '/api/auth/logout';
  static const String authMe = '/api/auth/me';

  /// Prefix of every auth endpoint; their bodies are never logged.
  static const String authPrefix = '/api/auth/';
}
