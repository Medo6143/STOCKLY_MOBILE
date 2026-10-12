import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/storage/preferences_store.dart';

/// The stored theme mode (`system` by default, design §7.7).
final class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    unawaited(_restore());
    return ThemeMode.system;
  }

  /// Stores [mode] and applies it.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref
        .read(preferencesStoreProvider)
        .write(PreferenceKey.themeMode, mode.name);
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(preferencesStoreProvider)
        .read(PreferenceKey.themeMode);
    final mode = ThemeMode.values.asNameMap()[stored];
    if (mode != null && ref.mounted) {
      state = mode;
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
