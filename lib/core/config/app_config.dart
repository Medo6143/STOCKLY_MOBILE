import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which backend the app talks to, chosen at build time with
/// `--dart-define=STOCKLY_BACKEND=fake|real` (default `real`).
enum BackendMode { real, fake }

/// Names of the `--dart-define` values the app reads.
abstract final class DartDefines {
  static const String backend = 'STOCKLY_BACKEND';
  static const String apiBaseUrl = 'STOCKLY_API_BASE_URL';
}

const String _backendDefine = String.fromEnvironment(DartDefines.backend);

/// `true` only in builds made with `STOCKLY_BACKEND=fake`. A `const`, so in
/// other builds the fake backend code is unreachable and tree-shaken.
const bool kFakeBackendEnabled = _backendDefine == 'fake';

/// Build-time configuration. The only configuration value is the API base
/// URL: the app holds no API keys (rule 38).
@immutable
final class AppConfig {
  const new({required this.backendMode, required this.apiBaseUrl});

  /// Reads the `--dart-define` values.
  factory fromEnvironment() => const AppConfig(
    backendMode: kFakeBackendEnabled ? BackendMode.fake : BackendMode.real,
    apiBaseUrl: kFakeBackendEnabled
        ? fakeApiBaseUrl
        : String.fromEnvironment(
            DartDefines.apiBaseUrl,
            defaultValue: defaultApiBaseUrl,
          ),
  );

  /// The Android emulator's address of the development machine.
  static const String defaultApiBaseUrl = 'http://10.0.2.2:5000';

  /// Never resolved: in fake mode the Dio adapter answers every request.
  static const String fakeApiBaseUrl = 'https://fake.stockly.invalid';

  final BackendMode backendMode;

  /// Scheme and host only; data sources use paths starting with `/api/`.
  final String apiBaseUrl;

  /// The only scheme a release build may talk to.
  static const String releaseScheme = 'https';

  /// Release builds must talk to the real backend (design §12.1) over
  /// HTTPS: a release build without `STOCKLY_API_BASE_URL` gets the
  /// `http://` emulator default and is refused too. A runtime check,
  /// because `assert` is removed from release builds.
  void ensureValidFor({required bool releaseMode}) {
    if (!releaseMode) {
      return;
    }
    if (backendMode != BackendMode.real) {
      throw StateError('Release builds must use STOCKLY_BACKEND=real.');
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
