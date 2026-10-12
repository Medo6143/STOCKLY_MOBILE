import 'package:drift/drift.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart';

part 'pending_scans_dao.g.dart';

/// Minimal access to the scan queue. The upload worker's queries arrive with
/// the scan queue brief.
@DriftAccessor(tables: [PendingScans])
class PendingScansDao extends DatabaseAccessor<AppDatabase>
    with _$PendingScansDaoMixin {
  new(super.attachedDatabase);

  Future<int> insertScan(PendingScansCompanion scan) =>
      into(pendingScans).insert(scan);

  /// The queue screen's query, served by `ix_pending_scans_shop_captured`.
  Future<List<PendingScan>> scansOfShop(String shopId) =>
      (select(pendingScans)
            ..where((s) => s.shopId.equals(shopId))
            ..orderBy([(s) => OrderingTerm.desc(s.capturedAt)]))
          .get();

  Future<int> deleteScan(String clientRequestId) => (delete(
    pendingScans,
  )..where((s) => s.clientRequestId.equals(clientRequestId))).go();
}
