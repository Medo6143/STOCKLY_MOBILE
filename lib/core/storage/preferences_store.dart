import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/daos/preferences_dao.dart';

/// Keys of the stored settings.
enum PreferenceKey { locale, themeMode }

/// Settings stored in the Drift `preferences` table.
abstract interface class PreferencesStore {
  Future<String?> read(PreferenceKey key);
  Future<void> write(PreferenceKey key, String value);
}

final class DriftPreferencesStore implements PreferencesStore {
  const new(this._dao);

  final PreferencesDao _dao;

  @override
  Future<String?> read(PreferenceKey key) => _dao.readValue(key.name);

  @override
  Future<void> write(PreferenceKey key, String value) =>
      _dao.writeValue(key.name, value);
}

final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => DriftPreferencesStore(ref.watch(appDatabaseProvider).preferencesDao),
);
