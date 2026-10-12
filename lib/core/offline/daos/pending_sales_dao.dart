import 'package:drift/drift.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';

part 'pending_sales_dao.g.dart';

/// Minimal access to sales with an unknown outcome. The quick-sale flow
/// arrives with the sales brief.
@DriftAccessor(tables: [PendingSales])
class PendingSalesDao extends DatabaseAccessor<AppDatabase>
    with _$PendingSalesDaoMixin {
  new(super.attachedDatabase);

  Future<void> insertSale(PendingSalesCompanion sale) =>
      into(pendingSales).insert(sale);

  Future<PendingSale?> saleById(String clientRequestId) => (select(
    pendingSales,
  )..where((s) => s.clientRequestId.equals(clientRequestId))).getSingleOrNull();

  Future<int> deleteSale(String clientRequestId) => (delete(
    pendingSales,
  )..where((s) => s.clientRequestId.equals(clientRequestId))).go();
}
