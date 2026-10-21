import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Names of the `--dart-define` values the app reads.
abstract final class DartDefines {
  static const String apiBaseUrl = 'STOCKLY_API_BASE_URL';
}

/// Build-time configuration. The only configuration value is the API base
/// URL: the app holds no API keys (rule 38). The app always talks to the
/// real API.
@immutable
final class AppConfig {
  const new({required this.apiBaseUrl});

  /// Reads the `--dart-define` values.
  factory fromEnvironment() => const AppConfig(
    apiBaseUrl: String.fromEnvironment(
      DartDefines.apiBaseUrl,
      defaultValue: defaultApiBaseUrl,
    ),
  );

  /// The Android emulator's address of the development machine.
  static const String defaultApiBaseUrl = 'http://10.0.2.2:5000';

  /// Scheme and host only; data sources use paths starting with `/api/`.
  final String apiBaseUrl;

  /// The only scheme a release build may talk to.
  static const String releaseScheme = 'https';

  /// Release builds must talk to the API over HTTPS: a release build
  /// without `STOCKLY_API_BASE_URL` gets the `http://` emulator default and
  /// is refused. A runtime check, because `assert` is removed from release
  /// builds.
  void ensureValidFor({required bool releaseMode}) {
    if (!releaseMode) {
      return;
    }
    final uri = Uri.tryParse(apiBaseUrl);
    if (uri == null || uri.scheme != releaseScheme || uri.host.isEmpty) {
      throw StateError('Release builds need an https STOCKLY_API_BASE_URL.');
    }
  }
}

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);
