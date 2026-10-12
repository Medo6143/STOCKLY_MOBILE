import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App logging. Callers log ids, sizes, codes and durations only: never
/// tokens, passwords, bodies or images (design §4.7).
abstract interface class AppLogger {
  void info(String message);
  void error(String message, {Object? error, StackTrace? stackTrace});
}

/// Prints in debug builds.
final class DebugPrintLogger implements AppLogger {
  const new();

  @override
  void info(String message) => debugPrint(message);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    debugPrint('$message ${error.runtimeType}');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

/// Logs nothing (release builds).
final class NoopLogger implements AppLogger {
  const new();

  @override
  void info(String message) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}
}

final appLoggerProvider = Provider<AppLogger>(
  (ref) => kDebugMode ? const DebugPrintLogger() : const NoopLogger(),
);
