import 'package:drift/drift.dart';

/// State of a sale whose outcome is unknown (design §6.8).
enum PendingSaleStatus { awaitingRetry, failedPermanent }

/// The exact `POST /api/sales` body of a sale whose outcome is unknown, so a
/// retry is byte-identical and reuses its `clientRequestId`.
class PendingSales extends Table {
  TextColumn get clientRequestId => text().withLength(min: 36, max: 36)();
  TextColumn get shopId => text()();
  TextColumn get userId => text()();
  TextColumn get requestJson => text()();
  TextColumn get status => textEnum<PendingSaleStatus>()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastErrorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {clientRequestId};
}
