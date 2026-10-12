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

/// The stored language choice (`system`, `ar` or `en`), shown in settings.
final class LocalePreferenceNotifier extends Notifier<LocalePreference> {
  /// `true` once a choice was made in this run: a late restore must not
  /// overwrite it.
  bool _chosen = false;

  @override
  LocalePreference build() {
    unawaited(_restore());
    return LocalePreference.system;
  }

  /// Stores [preference] and applies it.
  Future<void> set(LocalePreference preference) async {
    _chosen = true;
    state = preference;
    await ref
        .read(preferencesStoreProvider)
        .write(PreferenceKey.locale, preference.name);
  }

  Future<void> _restore() async {
    final stored = await ref
        .read(preferencesStoreProvider)
        .read(PreferenceKey.locale);
    final preference = LocalePreference.values.asNameMap()[stored];
    if (preference != null && ref.mounted && !_chosen) {
      state = preference;
    }
  }
}

final localePreferenceProvider =
    NotifierProvider<LocalePreferenceNotifier, LocalePreference>(
      LocalePreferenceNotifier.new,
    );

/// The resolved app locale (`ar` or `en`, never "system").
final class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() => _resolve(ref.watch(localePreferenceProvider));

  /// Stores [preference] and applies it.
  Future<void> setPreference(LocalePreference preference) =>
      ref.read(localePreferenceProvider.notifier).set(preference);

  /// Design §8.2: after a sign-in, while the preference is still `system`,
  /// the user's `preferredLanguage` ([languageCode]) becomes the explicit
  /// choice when it differs from the resolved locale.
  Future<void> adoptUserLanguage(String languageCode) async {
    if (ref.read(localePreferenceProvider) != LocalePreference.system ||
        languageCode == state.languageCode) {
      return;
    }
    final preference = LocalePreference.values.asNameMap()[languageCode];
    if (preference != null) {
      await setPreference(preference);
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
