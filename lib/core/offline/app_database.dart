import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/offline/daos/leases_dao.dart';
import 'package:stockly/core/offline/daos/pending_sales_dao.dart';
import 'package:stockly/core/offline/daos/pending_scans_dao.dart';
import 'package:stockly/core/offline/daos/preferences_dao.dart';
import 'package:stockly/core/offline/tables/leases.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart';
import 'package:stockly/core/offline/tables/preferences.dart';

part 'app_database.g.dart';

/// The local database (design §6.2): scan queue, pending sales, preferences
/// and cross-isolate leases. All four tables ship in schema version 1.
@DriftDatabase(
  tables: [PendingScans, PendingSales, Preferences, Leases],
  daos: [PendingScansDao, PendingSalesDao, PreferencesDao, LeasesDao],
)
class AppDatabase extends _$AppDatabase {
  new(super.e);

  /// Later changes use step-by-step migrations with a schema dump in
  /// `drift_schemas/` and a migration test.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode = WAL;');
      await customStatement('PRAGMA busy_timeout = $_busyTimeoutMs;');
    },
  );
}

/// The database file name, without the `.sqlite` extension.
const String appDatabaseName = 'stockly';

/// Busy timeout in milliseconds: two isolates (app and background sync) use
/// the same file.
const int _busyTimeoutMs = 5000;

/// Opens `<appSupportDir>/stockly.sqlite`.
AppDatabase openAppDatabase(AppDirectories directories) => AppDatabase(
  driftDatabase(
    name: appDatabaseName,
    native: DriftNativeOptions(
      databaseDirectory: () async => directories.supportDir,
      tempDirectoryPath: () async => directories.tempDir,
    ),
  ),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = openAppDatabase(ref.watch(appDirectoriesProvider));
  ref.onDispose(database.close);
  return database;
});
