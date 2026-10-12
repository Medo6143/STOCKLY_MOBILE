import 'package:drift/drift.dart';

/// Upload state of a queued invoice photo (design §6.3).
enum PendingScanStatus {
  queued,
  uploading,
  waitingRetry,
  rateLimited,
  quotaExceeded,
  failedPermanent,
}

/// Invoice photos waiting for upload. `shopId` is a local scope only and is
/// never sent: the shop comes from the token.
@TableIndex(
  name: 'ix_pending_scans_shop_status_next',
  columns: {#shopId, #status, #nextAttemptAt},
)
@TableIndex(
  name: 'ix_pending_scans_shop_captured',
  columns: {#shopId, #capturedAt},
)
class PendingScans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get clientRequestId =>
      text().withLength(min: 36, max: 36).unique()();
  TextColumn get shopId => text()();
  TextColumn get userId => text()();
  TextColumn get imagePath => text()();
  IntColumn get imageSizeBytes => integer()();
  TextColumn get mimeType => text()();
  TextColumn get status => textEnum<PendingScanStatus>()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  TextColumn get lastCorrelationId => text().nullable()();
  DateTimeColumn get capturedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
