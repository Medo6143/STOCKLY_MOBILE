import 'package:drift/drift.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart';

part 'pending_scans_dao.g.dart';

/// The scan queue's queries (design §6.2). Every query is scoped to one
/// shop: rows of another shop are never shown or uploaded (§6.7).
@DriftAccessor(tables: [PendingScans])
class PendingScansDao extends DatabaseAccessor<AppDatabase>
    with _$PendingScansDaoMixin {
  new(super.attachedDatabase);

  /// Rows the worker may upload: everything except `uploading` and
  /// `failedPermanent`.
  static const List<PendingScanStatus> waitingStatuses = [
    PendingScanStatus.queued,
    PendingScanStatus.waitingRetry,
    PendingScanStatus.rateLimited,
    PendingScanStatus.quotaExceeded,
  ];

  Future<int> insertScan(PendingScansCompanion scan) =>
      into(pendingScans).insert(scan);

  SimpleSelectStatement<$PendingScansTable, PendingScan> _ofShopNewestFirst(
    String shopId,
  ) => select(pendingScans)
    ..where((s) => s.shopId.equals(shopId))
    ..orderBy([(s) => OrderingTerm.desc(s.capturedAt)]);

  /// The queue screen's query, served by `ix_pending_scans_shop_captured`.
  Future<List<PendingScan>> scansOfShop(String shopId) =>
      _ofShopNewestFirst(shopId).get();

  /// [scansOfShop], re-emitted on every change.
  Stream<List<PendingScan>> watchScansOfShop(String shopId) =>
      _ofShopNewestFirst(shopId).watch();

  /// Rows of [shopId] not uploaded yet (the tab badge).
  Stream<int> watchCountOfShop(String shopId) =>
      _countQuery(shopId).watchSingle();

  Future<int> countOfShop(String shopId) => _countQuery(shopId).getSingle();

  Selectable<int> _countQuery(String shopId) {
    final count = pendingScans.id.count();
    return (selectOnly(pendingScans)
          ..addColumns([count])
          ..where(pendingScans.shopId.equals(shopId)))
        .map((row) => row.read(count) ?? 0);
  }

  Future<PendingScan?> scanById(String clientRequestId) => (select(
    pendingScans,
  )..where((s) => s.clientRequestId.equals(clientRequestId))).getSingleOrNull();

  /// Waiting rows of [shopId] whose `nextAttemptAt` has passed at [now] (any
  /// when [force]), oldest capture first. Served by
  /// `ix_pending_scans_shop_status_next`.
  Future<List<PendingScan>> dueScans(
    String shopId, {
    required DateTime now,
    required bool force,
  }) =>
      (select(pendingScans)
            ..where((s) {
              final waiting =
                  s.shopId.equals(shopId) &
                  s.status.isInValues(waitingStatuses);
              return force
                  ? waiting
                  : waiting &
                        (s.nextAttemptAt.isNull() |
                            s.nextAttemptAt.isSmallerOrEqualValue(now));
            })
            ..orderBy([(s) => OrderingTerm.asc(s.capturedAt)]))
          .get();

  /// The earliest `nextAttemptAt` of the waiting rows of [shopId].
  Future<DateTime?> earliestNextAttempt(String shopId) async {
    final earliest = pendingScans.nextAttemptAt.min();
    final query = selectOnly(pendingScans)
      ..addColumns([earliest])
      ..where(
        pendingScans.shopId.equals(shopId) &
            pendingScans.status.isInValues(waitingStatuses) &
            pendingScans.nextAttemptAt.isNotNull(),
      );
    return (await query.getSingle()).read(earliest);
  }

  Future<int> updateScan(String clientRequestId, PendingScansCompanion scan) =>
      (update(
        pendingScans,
      )..where((s) => s.clientRequestId.equals(clientRequestId))).write(scan);

  /// Rows left in `uploading` since before [cutoff] (the app was killed
  /// mid-upload) go back to `queued`. Safe: the same `clientRequestId` is
  /// sent again.
  Future<int> resetStuckUploads({
    required DateTime cutoff,
    required DateTime now,
  }) =>
      (update(pendingScans)..where(
            (s) =>
                s.status.equalsValue(PendingScanStatus.uploading) &
                s.updatedAt.isSmallerThanValue(cutoff),
          ))
          .write(
            PendingScansCompanion(
              status: const Value(PendingScanStatus.queued),
              updatedAt: Value(now),
            ),
          );

  /// Every row of [shopId] that may still upload waits for the quota.
  Future<int> markQuotaExceeded(
    String shopId, {
    required DateTime now,
    required DateTime nextAttemptAt,
    required String errorCode,
  }) =>
      (update(pendingScans)..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.isNotInValues([PendingScanStatus.failedPermanent]),
          ))
          .write(
            PendingScansCompanion(
              status: const Value(PendingScanStatus.quotaExceeded),
              nextAttemptAt: Value(nextAttemptAt),
              lastErrorCode: Value(errorCode),
              updatedAt: Value(now),
            ),
          );

  Future<int> deleteScan(String clientRequestId) => (delete(
    pendingScans,
  )..where((s) => s.clientRequestId.equals(clientRequestId))).go();
}
