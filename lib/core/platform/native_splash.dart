import 'package:flutter/widgets.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The native launch screen drawn by `flutter_native_splash` (design
/// §10.1). Kept up in `bootstrap()` until the animated splash has drawn its
/// first frame, so there is no flash between the two.
abstract interface class NativeSplash {
  /// Hands over to Flutter's first frame.
  void remove();
}

final class PluginNativeSplash implements NativeSplash {
  const new();

  /// Keeps the native splash on screen while [binding] defers the first
  /// frame. Called once in `bootstrap()`.
  static void preserve(WidgetsBinding binding) =>
      FlutterNativeSplash.preserve(widgetsBinding: binding);

  @override
  void remove() => FlutterNativeSplash.remove();
}

final nativeSplashProvider = Provider<NativeSplash>(
  (ref) => const PluginNativeSplash(),
);
