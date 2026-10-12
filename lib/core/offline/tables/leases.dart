import 'package:drift/drift.dart';

/// Cross-isolate mutual exclusion: one row per held lease.
class Leases extends Table {
  TextColumn get name => text()();
  TextColumn get holder => text()();
  DateTimeColumn get expiresAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {name};
}
