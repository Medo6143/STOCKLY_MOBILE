import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';

/// Runtime switches of the fake backend, flipped by the debug
/// `FakeBackendPanel` (design §12.1). Fake mode only.
final class FakeBackendControls {
  new(FakeBackendConfig config)
    : lockoutEnabled = config.lockoutEnabled,
      rateLimitEnabled = config.rateLimitEnabled;

  /// Every request fails as if the device had no connection.
  bool offline = false;

  /// The next request fails with this code, then it is cleared.
  ApiErrorCode? failNextWith;

  /// Account lockout after repeated failed logins (contract v1.4).
  bool lockoutEnabled;

  /// Login and register rate limiting (contract v1.4).
  bool rateLimitEnabled;

  /// The daily scan quota is used up: every new scan gets
  /// `429 Scan.DailyQuotaExceeded` (design §12.1 "set the daily quota to
  /// 0").
  bool scanQuotaExhausted = false;
}
