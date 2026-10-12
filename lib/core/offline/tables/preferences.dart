import 'package:drift/drift.dart';

/// App settings (locale, theme mode) as key/value rows.
class Preferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
