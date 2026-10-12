import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/storage/preferences_store.dart';

/// The stored language choice (design §8.2).
enum LocalePreference { system, ar, en }

/// The languages the app supports. Arabic is the default.
abstract final class AppLocales {
  static const Locale arabic = Locale('ar');
  static const Locale english = Locale('en');
  static const List<Locale> supported = [arabic, english];
}

/// The device language, overridable in tests.
final deviceLocaleProvider = Provider<Locale>(
  (ref) => PlatformDispatcher.instance.locale,
);

/// The resolved app locale (`ar` or `en`, never "system").
final class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    unawaited(_restore());
    return _resolve(LocalePreference.system);
  }

  /// Stores [preference] and applies it.
  Future<void> setPreference(LocalePreference preference) async {
    state = _resolve(preference);
    await ref
        .read(preferencesStoreProvider)
        .write(PreferenceKey.locale, preference.name);
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(preferencesStoreProvider)
        .read(PreferenceKey.locale);
    final preference = LocalePreference.values.asNameMap()[stored];
    if (preference != null && ref.mounted) {
      state = _resolve(preference);
    }
  }

  Locale _resolve(LocalePreference preference) => switch (preference) {
    LocalePreference.ar => AppLocales.arabic,
    LocalePreference.en => AppLocales.english,
    LocalePreference.system =>
      ref.read(deviceLocaleProvider).languageCode ==
              AppLocales.english.languageCode
          ? AppLocales.english
          : AppLocales.arabic,
  };
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
