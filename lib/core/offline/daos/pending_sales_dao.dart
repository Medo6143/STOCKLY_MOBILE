import 'package:drift/drift.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';

part 'pending_sales_dao.g.dart';

/// Sales whose outcome is not known yet (design §6.8). Shop queries are
/// scoped to one shop: another account's rows are never shown or sent.
@DriftAccessor(tables: [PendingSales])
class PendingSalesDao extends DatabaseAccessor<AppDatabase>
    with _$PendingSalesDaoMixin {
  new(super.attachedDatabase);

  Future<void> insertSale(PendingSalesCompanion sale) =>
      into(pendingSales).insert(sale);

  Future<PendingSale?> saleById(String clientRequestId) => (select(
    pendingSales,
  )..where((s) => s.clientRequestId.equals(clientRequestId))).getSingleOrNull();

  SimpleSelectStatement<$PendingSalesTable, PendingSale> _oldestOfShop(
    String shopId,
  ) => select(pendingSales)
    ..where((s) => s.shopId.equals(shopId))
    ..orderBy([(s) => OrderingTerm.asc(s.createdAt)])
    ..limit(1);

  /// The oldest sale of [shopId] whose outcome is unknown, or `null`.
  Future<PendingSale?> oldestOfShop(String shopId) =>
      _oldestOfShop(shopId).getSingleOrNull();

  /// [oldestOfShop], emitted again on every change.
  Stream<PendingSale?> watchOldestOfShop(String shopId) =>
      _oldestOfShop(shopId).watchSingleOrNull();

  Future<int> updateSale(String clientRequestId, PendingSalesCompanion sale) =>
      (update(
        pendingSales,
      )..where((s) => s.clientRequestId.equals(clientRequestId))).write(sale);

  Future<int> deleteSale(String clientRequestId) => (delete(
    pendingSales,
  )..where((s) => s.clientRequestId.equals(clientRequestId))).go();
}
