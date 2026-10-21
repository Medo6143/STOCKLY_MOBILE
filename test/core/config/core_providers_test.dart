import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/network/http_adapter_override.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/preferences/theme_mode_notifier.dart';
import 'package:stockly/core/storage/preferences_store.dart';
import 'package:stockly/core/time/clock.dart';

import '../../helpers/test_doubles.dart';

ProviderContainer _container(
  InMemoryPreferencesStore store, {
  Locale device = const Locale('ar'),
}) => ProviderContainer.test(
  overrides: [
    preferencesStoreProvider.overrideWithValue(store),
    deviceLocaleProvider.overrideWithValue(device),
  ],
);

void main() {
  group('AppConfig', () {
    test('fromEnvironment_DefaultsToTheEmulatorApi', () {
      final config = AppConfig.fromEnvironment();
      expect(config.apiBaseUrl, AppConfig.defaultApiBaseUrl);
    });

    test('ensureValidFor_ReleaseAcceptsAnHttpsApi', () {
      const real = AppConfig(apiBaseUrl: 'https://api.stockly.example');

      expect(() => real.ensureValidFor(releaseMode: true), returnsNormally);
    });

    test('ensureValidFor_ReleaseRefusesHttpBaseUrl', () {
      const http = AppConfig(apiBaseUrl: AppConfig.defaultApiBaseUrl);
      const malformed = AppConfig(apiBaseUrl: 'api.stockly.example');

      // Without STOCKLY_API_BASE_URL a release build gets the http
      // emulator default: refused.
      expect(() => http.ensureValidFor(releaseMode: true), throwsStateError);
      expect(
        () => malformed.ensureValidFor(releaseMode: true),
        throwsStateError,
      );
      // Debug builds keep talking to the emulator host over http.
      expect(() => http.ensureValidFor(releaseMode: false), returnsNormally);
    });

    test('httpAdapterOverride_NullSoTheAppUsesTheNetwork', () {
      expect(
        ProviderContainer.test().read(httpAdapterOverrideProvider),
        isNull,
      );
    });
  });

  test('CoreDefaults', () {
    final container = ProviderContainer.test();
    final uuid = container.read(uuidGeneratorProvider).v4();
    expect(uuid, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(uuid[14], '4');
    expect(container.read(clockProvider).now().isUtc, isTrue);
    expect(container.read(appLoggerProvider), isA<DebugPrintLogger>());
    expect(() => container.read(appDirectoriesProvider), throwsA(anything));
    const NoopLogger()
      ..info('ignored')
      ..error('ignored');
    const DebugPrintLogger()
      ..info('log line')
      ..error(
        'error line',
        error: StateError('x'),
        stackTrace: StackTrace.empty,
      );
  });

  group('LocaleNotifier', () {
    test('System_ArabicDevice_Arabic', () {
      expect(
        _container(InMemoryPreferencesStore()).read(localeProvider),
        AppLocales.arabic,
      );
    });

    test('System_EnglishDevice_English', () {
      expect(
        _container(
          InMemoryPreferencesStore(),
          device: const Locale('en', 'US'),
        ).read(localeProvider),
        AppLocales.english,
      );
    });

    test('System_OtherLanguage_ArabicDefault', () {
      expect(
        _container(
          InMemoryPreferencesStore(),
          device: const Locale('fr'),
        ).read(localeProvider),
        AppLocales.arabic,
      );
    });

    test('StoredPreference_IsRestored', () async {
      final store = InMemoryPreferencesStore()
        ..values[PreferenceKey.locale] = 'en';
      final container = _container(store)..listen(localeProvider, (_, _) {});
      await pumpEventQueue();

      expect(container.read(localeProvider), AppLocales.english);
    });

    test('SetPreference_AppliesAndStores', () async {
      final store = InMemoryPreferencesStore();
      final container = _container(store, device: const Locale('en'))
        ..listen(localeProvider, (_, _) {});

      await container
          .read(localeProvider.notifier)
          .setPreference(LocalePreference.ar);

      expect(container.read(localeProvider), AppLocales.arabic);
      expect(store.values[PreferenceKey.locale], 'ar');

      await container
          .read(localeProvider.notifier)
          .setPreference(LocalePreference.system);
      expect(container.read(localeProvider), AppLocales.english);
    });

    test('LocalePreference_IsExposedForSettings', () async {
      final store = InMemoryPreferencesStore()
        ..values[PreferenceKey.locale] = 'en';
      final container = _container(store)
        ..listen(localePreferenceProvider, (_, _) {});
      await pumpEventQueue();

      expect(container.read(localePreferenceProvider), LocalePreference.en);
    });

    test('AdoptUserLanguage_WhileSystem_BecomesTheExplicitChoice', () async {
      final store = InMemoryPreferencesStore();
      final container = _container(store, device: const Locale('en'))
        ..listen(localeProvider, (_, _) {});

      await container.read(localeProvider.notifier).adoptUserLanguage('ar');

      expect(container.read(localeProvider), AppLocales.arabic);
      expect(container.read(localePreferenceProvider), LocalePreference.ar);
      expect(store.values[PreferenceKey.locale], 'ar');
    });

    test('AdoptUserLanguage_ExplicitChoiceOrSameLanguage_Unchanged', () async {
      final store = InMemoryPreferencesStore();
      final container = _container(store)..listen(localeProvider, (_, _) {});

      await container.read(localeProvider.notifier).adoptUserLanguage('ar');
      expect(container.read(localePreferenceProvider), LocalePreference.system);

      await container
          .read(localeProvider.notifier)
          .setPreference(LocalePreference.ar);
      await container.read(localeProvider.notifier).adoptUserLanguage('en');
      expect(container.read(localeProvider), AppLocales.arabic);
    });

    test('LateRestore_DoesNotOverwriteAChoice', () async {
      final store = InMemoryPreferencesStore()
        ..values[PreferenceKey.locale] = 'en';
      final container = _container(store)..listen(localeProvider, (_, _) {});

      await container
          .read(localeProvider.notifier)
          .setPreference(LocalePreference.ar);
      await pumpEventQueue();

      expect(container.read(localeProvider), AppLocales.arabic);
    });
  });

  group('ThemeModeNotifier', () {
    test('Default_System', () {
      expect(
        _container(InMemoryPreferencesStore()).read(themeModeProvider),
        ThemeMode.system,
      );
    });

    test('StoredMode_IsRestored_AndUnknownIgnored', () async {
      final store = InMemoryPreferencesStore()
        ..values[PreferenceKey.themeMode] = 'dark';
      final container = _container(store)..listen(themeModeProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(themeModeProvider), ThemeMode.dark);

      final garbage = InMemoryPreferencesStore()
        ..values[PreferenceKey.themeMode] = 'sepia';
      final other = _container(garbage)..listen(themeModeProvider, (_, _) {});
      await pumpEventQueue();
      expect(other.read(themeModeProvider), ThemeMode.system);
    });

    test('SetThemeMode_AppliesAndStores', () async {
      final store = InMemoryPreferencesStore();
      final container = _container(store)..listen(themeModeProvider, (_, _) {});

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(store.values[PreferenceKey.themeMode], 'light');
    });
  });
}
