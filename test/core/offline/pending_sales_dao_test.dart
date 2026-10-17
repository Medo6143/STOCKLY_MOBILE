import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';

const String _shopA = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d01';
const String _shopB = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d0b';
final DateTime _t0 = DateTime.utc(2026, 10, 12, 7);

String _id(int n) => '0192f0a0-6c1e-7b3a-9d2e-5a1e${'$n'.padLeft(8, '0')}';

PendingSalesCompanion _sale(
  int n, {
  String shopId = _shopA,
  Duration createdAfter = Duration.zero,
}) => PendingSalesCompanion.insert(
  clientRequestId: _id(n),
  shopId: shopId,
  userId: 'user-1',
  requestJson: '{"clientRequestId":"${_id(n)}"}',
  status: PendingSaleStatus.awaitingRetry,
  createdAt: _t0.add(createdAfter),
  updatedAt: _t0.add(createdAfter),
);

/// Design §6.8: the pending-sales queries, scoped to one shop.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('OldestOfShop_ScopedAndOldestFirst', () async {
    final dao = db.pendingSalesDao;
    expect(await dao.oldestOfShop(_shopA), isNull);
    await dao.insertSale(_sale(1, createdAfter: const Duration(minutes: 2)));
    await dao.insertSale(_sale(2));
    await dao.insertSale(
      _sale(3, shopId: _shopB, createdAfter: -const Duration(hours: 1)),
    );

    expect((await dao.oldestOfShop(_shopA))?.clientRequestId, _id(2));
    expect((await dao.oldestOfShop(_shopB))?.clientRequestId, _id(3));
  });

  test('ClientRequestIdIsThePrimaryKey', () async {
    final dao = db.pendingSalesDao;
    await dao.insertSale(_sale(1));

    expect(() => dao.insertSale(_sale(1)), throwsA(isA<SqliteException>()));
  });

  test('WatchOldestOfShop_EmitsOnChange', () async {
    final dao = db.pendingSalesDao;
    final emitted = <String?>[];
    final sub = dao
        .watchOldestOfShop(_shopA)
        .listen((row) => emitted.add(row?.clientRequestId));
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await dao.insertSale(_sale(1));
    await pumpEventQueue();
    await dao.deleteSale(_id(1));
    await pumpEventQueue();

    expect(emitted, [null, _id(1), null]);
  });

  test('UpdateSale_AttemptAndErrorCode', () async {
    final dao = db.pendingSalesDao;
    await dao.insertSale(_sale(1));

    await dao.updateSale(
      _id(1),
      PendingSalesCompanion(
        attemptCount: const Value(2),
        lastErrorCode: const Value('Server.Unexpected'),
        updatedAt: Value(_t0.add(const Duration(minutes: 1))),
      ),
    );

    final row = (await dao.saleById(_id(1)))!;
    expect(row.attemptCount, 2);
    expect(row.lastErrorCode, 'Server.Unexpected');
    expect(row.requestJson, '{"clientRequestId":"${_id(1)}"}');
    expect(row.status, PendingSaleStatus.awaitingRetry);
  });
}
