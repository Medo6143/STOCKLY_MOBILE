import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart';

const String _shopA = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d01';
const String _shopB = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d0b';
final DateTime _t0 = DateTime.utc(2026, 10, 12, 7);

String _id(int n) => '0192f0a0-6c1e-7b3a-9d2e-${'$n'.padLeft(12, '0')}';

PendingScansCompanion _scan(
  int n, {
  String shopId = _shopA,
  PendingScanStatus status = PendingScanStatus.queued,
  DateTime? nextAttemptAt,
  Duration capturedAfter = Duration.zero,
}) => PendingScansCompanion.insert(
  clientRequestId: _id(n),
  shopId: shopId,
  userId: 'user-1',
  imagePath: '/support/pending_scans/${_id(n)}.jpg',
  imageSizeBytes: 1024,
  mimeType: 'image/jpeg',
  status: status,
  nextAttemptAt: Value(nextAttemptAt),
  capturedAt: _t0.add(capturedAfter),
  updatedAt: _t0.add(capturedAfter),
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('DueScans_WaitingRowsOfTheShopDueNow_OldestFirst', () async {
    final dao = db.pendingScansDao;
    await dao.insertScan(_scan(1, capturedAfter: const Duration(minutes: 2)));
    await dao.insertScan(_scan(2));
    await dao.insertScan(
      _scan(
        3,
        status: PendingScanStatus.waitingRetry,
        nextAttemptAt: _t0.add(const Duration(minutes: 5)),
      ),
    );
    await dao.insertScan(
      _scan(
        4,
        status: PendingScanStatus.rateLimited,
        nextAttemptAt: _t0.subtract(const Duration(seconds: 1)),
      ),
    );
    await dao.insertScan(_scan(5, status: PendingScanStatus.failedPermanent));
    await dao.insertScan(_scan(6, status: PendingScanStatus.uploading));
    await dao.insertScan(_scan(7, shopId: _shopB));

    final due = await dao.dueScans(_shopA, now: _t0, force: false);
    final forced = await dao.dueScans(_shopA, now: _t0, force: true);

    expect(due.map((s) => s.clientRequestId), [_id(2), _id(4), _id(1)]);
    expect(forced.map((s) => s.clientRequestId), [
      _id(2),
      _id(3),
      _id(4),
      _id(1),
    ]);
  });

  test('EarliestNextAttempt_OfWaitingRowsOnly', () async {
    final dao = db.pendingScansDao;
    expect(await dao.earliestNextAttempt(_shopA), isNull);
    await dao.insertScan(
      _scan(
        1,
        status: PendingScanStatus.waitingRetry,
        nextAttemptAt: _t0.add(const Duration(minutes: 5)),
      ),
    );
    await dao.insertScan(
      _scan(
        2,
        status: PendingScanStatus.quotaExceeded,
        nextAttemptAt: _t0.add(const Duration(minutes: 1)),
      ),
    );
    await dao.insertScan(
      _scan(3, status: PendingScanStatus.failedPermanent, nextAttemptAt: _t0),
    );

    expect(
      await dao.earliestNextAttempt(_shopA),
      _t0.add(const Duration(minutes: 1)),
    );
  });

  test('Count_AndWatch_PerShop', () async {
    final dao = db.pendingScansDao;
    await dao.insertScan(_scan(1));
    await dao.insertScan(_scan(2, status: PendingScanStatus.failedPermanent));
    await dao.insertScan(_scan(3, shopId: _shopB));

    expect(await dao.countOfShop(_shopA), 2);
    expect(await dao.watchCountOfShop(_shopA).first, 2);
    expect(
      (await dao.watchScansOfShop(_shopB).first).single.clientRequestId,
      _id(3),
    );
  });

  test('ResetStuckUploads_OnlyOlderThanTheCutoff', () async {
    final dao = db.pendingScansDao;
    await dao.insertScan(_scan(1, status: PendingScanStatus.uploading));
    await dao.insertScan(
      _scan(
        2,
        status: PendingScanStatus.uploading,
        capturedAfter: const Duration(minutes: 10),
      ),
    );

    await dao.resetStuckUploads(
      cutoff: _t0.add(const Duration(minutes: 5)),
      now: _t0.add(const Duration(minutes: 11)),
    );

    expect((await dao.scanById(_id(1)))!.status, PendingScanStatus.queued);
    expect((await dao.scanById(_id(2)))!.status, PendingScanStatus.uploading);
  });

  test('MarkQuotaExceeded_EveryRowOfTheShopButFailed', () async {
    final dao = db.pendingScansDao;
    await dao.insertScan(_scan(1));
    await dao.insertScan(_scan(2, status: PendingScanStatus.failedPermanent));
    await dao.insertScan(_scan(3, shopId: _shopB));
    final next = _t0.add(const Duration(hours: 1));

    await dao.markQuotaExceeded(
      _shopA,
      now: _t0,
      nextAttemptAt: next,
      errorCode: 'Scan.DailyQuotaExceeded',
    );

    final one = (await dao.scanById(_id(1)))!;
    expect(one.status, PendingScanStatus.quotaExceeded);
    expect(one.nextAttemptAt, next);
    expect(one.lastErrorCode, 'Scan.DailyQuotaExceeded');
    expect(
      (await dao.scanById(_id(2)))!.status,
      PendingScanStatus.failedPermanent,
    );
    expect((await dao.scanById(_id(3)))!.status, PendingScanStatus.queued);
  });

  test('UpdateAndDelete_ByClientRequestId', () async {
    final dao = db.pendingScansDao;
    await dao.insertScan(_scan(1));

    await dao.updateScan(
      _id(1),
      const PendingScansCompanion(attemptCount: Value(3)),
    );
    expect((await dao.scanById(_id(1)))!.attemptCount, 3);

    await dao.deleteScan(_id(1));
    expect(await dao.scanById(_id(1)), isNull);
  });
}
