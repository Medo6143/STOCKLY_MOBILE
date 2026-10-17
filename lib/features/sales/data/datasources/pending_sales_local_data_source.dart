import 'package:drift/drift.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/daos/pending_sales_dao.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';
import 'package:stockly/core/time/clock.dart';

/// The `pending_sales` rows (design §6.8) behind the sales repository.
final class PendingSalesLocalDataSource {
  const new(this._dao, this._clock);

  final PendingSalesDao _dao;
  final Clock _clock;

  Future<PendingSale?> byId(String clientRequestId) =>
      _dao.saleById(clientRequestId);

  Future<PendingSale?> oldestOfShop(String shopId) => _dao.oldestOfShop(shopId);

  Stream<PendingSale?> watchOldestOfShop(String shopId) =>
      _dao.watchOldestOfShop(shopId);

  /// Stores [requestJson] before its first send.
  Future<void> insert({
    required String clientRequestId,
    required String shopId,
    required String userId,
    required String requestJson,
  }) {
    final now = _clock.now();
    return _dao.insertSale(
      PendingSalesCompanion.insert(
        clientRequestId: clientRequestId,
        shopId: shopId,
        userId: userId,
        requestJson: requestJson,
        status: PendingSaleStatus.awaitingRetry,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// One more attempt whose outcome is unknown.
  Future<void> recordUnknownOutcome(
    PendingSale sale, {
    required String? errorCode,
  }) => _dao.updateSale(
    sale.clientRequestId,
    PendingSalesCompanion(
      attemptCount: Value(sale.attemptCount + 1),
      lastErrorCode: Value(errorCode),
      updatedAt: Value(_clock.now()),
    ),
  );

  Future<void> delete(String clientRequestId) =>
      _dao.deleteSale(clientRequestId);
}
