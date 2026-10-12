import 'package:drift/drift.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/preferences.dart';

part 'preferences_dao.g.dart';

@DriftAccessor(tables: [Preferences])
class PreferencesDao extends DatabaseAccessor<AppDatabase>
    with _$PreferencesDaoMixin {
  new(super.attachedDatabase);

  Future<String?> readValue(String key) async {
    final row = await (select(
      preferences,
    )..where((p) => p.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> writeValue(String key, String value) => into(
    preferences,
  ).insertOnConflictUpdate(PreferencesCompanion.insert(key: key, value: value));
}
