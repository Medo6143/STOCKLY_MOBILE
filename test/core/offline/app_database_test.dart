import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/offline/tables/pending_sales.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart';
import 'package:stockly/core/storage/preferences_store.dart';

import '../../helpers/test_doubles.dart';

const String _shopA = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d01';
const String _shopB = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d0b';

PendingScansCompanion _scan(String id, String shopId, DateTime capturedAt) =>
    PendingScansCompanion.insert(
      clientRequestId: id,
      shopId: shopId,
      userId: 'user-1',
      imagePath: '/support/pending_scans/$id.jpg',
      imageSizeBytes: 1024,
      mimeType: 'image/jpeg',
      status: PendingScanStatus.queued,
      capturedAt: capturedAt,
      updatedAt: capturedAt,
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('schema_VersionOneWithAllFourTablesAndIndexes', () async {
    expect(db.schemaVersion, 1);
    final rows = await db
        .customSelect(
          'SELECT type, name FROM sqlite_master '
          "WHERE type IN ('table', 'index')",
        )
        .get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'pending_scans',
        'pending_sales',
        'preferences',
        'leases',
        'ix_pending_scans_shop_status_next',
        'ix_pending_scans_shop_captured',
      ]),
    );
  });

  test('pendingScans_ClientRequestIdIsUnique', () async {
    final dao = db.pendingScansDao;
    final now = DateTime.utc(2026, 10, 12);
    const id = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d10';
    await dao.insertScan(_scan(id, _shopA, now));

    expect(
      () => dao.insertScan(_scan(id, _shopA, now)),
      throwsA(isA<SqliteException>()),
    );
  });

  test('pendingScans_ScansOfShop_NewestFirstAndScoped', () async {
    final dao = db.pendingScansDao;
    final t0 = DateTime.utc(2026, 10, 12, 8);
    await dao.insertScan(
      _scan('0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d11', _shopA, t0),
    );
    await dao.insertScan(
      _scan(
        '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d12',
        _shopA,
        t0.add(const Duration(minutes: 1)),
      ),
    );
    await dao.insertScan(
      _scan('0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d13', _shopB, t0),
    );

    final scans = await dao.scansOfShop(_shopA);

    expect(scans.map((s) => s.clientRequestId), [
      '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d12',
      '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d11',
    ]);
    expect(scans.first.status, PendingScanStatus.queued);
    expect(scans.first.attemptCount, 0);
    expect(scans.first.capturedAt, t0.add(const Duration(minutes: 1)));

    expect(await dao.deleteScan('0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d12'), 1);
    expect(await dao.scansOfShop(_shopA), hasLength(1));
  });

  test('pendingScans_ClientRequestIdMustBe36Chars', () async {
    expect(
      () => db.pendingScansDao.insertScan(
        _scan('short', _shopA, DateTime.utc(2026)),
      ),
      throwsA(isA<InvalidDataException>()),
    );
  });

  test('pendingSales_InsertReadDelete', () async {
    final dao = db.pendingSalesDao;
    const id = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d20';
    final now = DateTime.utc(2026, 10, 12);
    await dao.insertSale(
      PendingSalesCompanion.insert(
        clientRequestId: id,
        shopId: _shopA,
        userId: 'user-1',
        requestJson: '{"clientRequestId":"$id","items":[]}',
        status: PendingSaleStatus.awaitingRetry,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final sale = await dao.saleById(id);
    expect(sale?.requestJson, '{"clientRequestId":"$id","items":[]}');
    expect(sale?.status, PendingSaleStatus.awaitingRetry);

    expect(await dao.deleteSale(id), 1);
    expect(await dao.saleById(id), isNull);
  });

  test('preferencesStore_WriteThenReadAndOverwrite', () async {
    final store = DriftPreferencesStore(db.preferencesDao);

    expect(await store.read(PreferenceKey.locale), isNull);
    await store.write(PreferenceKey.locale, 'en');
    await store.write(PreferenceKey.locale, 'ar');
    await store.write(PreferenceKey.themeMode, 'dark');

    expect(await store.read(PreferenceKey.locale), 'ar');
    expect(await store.read(PreferenceKey.themeMode), 'dark');
  });

  group('leases', () {
    test('tryAcquire_FreeHeldExpiredAndSameHolder', () async {
      final dao = db.leasesDao;
      final now = DateTime.utc(2026, 10, 12, 8);
      final later = now.add(const Duration(seconds: 30));

      expect(
        await dao.tryAcquire(
          name: LeaseNames.authRefresh,
          holder: 'a',
          now: now,
          expiresAt: later,
        ),
        isTrue,
      );
      expect(
        await dao.tryAcquire(
          name: LeaseNames.authRefresh,
          holder: 'b',
          now: now,
          expiresAt: later,
        ),
        isFalse,
      );
      expect(
        await dao.tryAcquire(
          name: LeaseNames.authRefresh,
          holder: 'a',
          now: now,
          expiresAt: later,
        ),
        isTrue,
      );
      expect(
        await dao.tryAcquire(
          name: LeaseNames.authRefresh,
          holder: 'b',
          now: later,
          expiresAt: later.add(const Duration(seconds: 30)),
        ),
        isTrue,
        reason: 'an expired lease is free',
      );
    });

    test('release_OnlyByHolder', () async {
      final dao = db.leasesDao;
      final now = DateTime.utc(2026, 10, 12, 8);
      final later = now.add(const Duration(seconds: 30));
      await dao.tryAcquire(
        name: LeaseNames.authRefresh,
        holder: 'a',
        now: now,
        expiresAt: later,
      );

      await dao.release(name: LeaseNames.authRefresh, holder: 'b');
      expect(
        await dao.tryAcquire(
          name: LeaseNames.authRefresh,
          holder: 'b',
          now: now,
          expiresAt: later,
        ),
        isFalse,
      );

      await dao.release(name: LeaseNames.authRefresh, holder: 'a');
      expect(
        await dao.tryAcquire(
          name: LeaseNames.authRefresh,
          holder: 'b',
          now: now,
          expiresAt: later,
        ),
        isTrue,
      );
    });

    test('withLease_RunsActionAndReleases', () async {
      final clock = FakeClock();
      final first = DriftLeaseService(db.leasesDao, clock, holder: 'a');
      final second = DriftLeaseService(db.leasesDao, clock, holder: 'b');

      final result = await first.withLease(
        LeaseNames.authRefresh,
        ttl: LeaseTimings.authRefreshTtl,
        wait: Duration.zero,
        action: () async => 42,
      );
      final afterRelease = await second.withLease(
        LeaseNames.authRefresh,
        ttl: LeaseTimings.authRefreshTtl,
        wait: Duration.zero,
        action: () async => 'b ran',
      );

      expect(result, 42);
      expect(afterRelease, 'b ran');
    });

    test('withLease_ReleasesEvenWhenActionThrows', () async {
      final clock = FakeClock();
      final first = DriftLeaseService(db.leasesDao, clock, holder: 'a');
      final second = DriftLeaseService(db.leasesDao, clock, holder: 'b');

      await expectLater(
        first.withLease<void>(
          LeaseNames.authRefresh,
          ttl: LeaseTimings.authRefreshTtl,
          wait: Duration.zero,
          action: () async => throw StateError('boom'),
        ),
        throwsStateError,
      );

      expect(
        await second.withLease(
          LeaseNames.authRefresh,
          ttl: LeaseTimings.authRefreshTtl,
          wait: Duration.zero,
          action: () async => true,
        ),
        isTrue,
      );
    });

    test('withLease_BusyLongerThanWait_ReturnsNullWithoutRunning', () async {
      final clock = FakeClock();
      final now = clock.now();
      await db.leasesDao.tryAcquire(
        name: LeaseNames.authRefresh,
        holder: 'other-isolate',
        now: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      final service = DriftLeaseService(db.leasesDao, clock, holder: 'me');
      var ran = false;

      final result = await service.withLease(
        LeaseNames.authRefresh,
        ttl: LeaseTimings.authRefreshTtl,
        wait: Duration.zero,
        action: () async => ran = true,
      );

      expect(result, isNull);
      expect(ran, isFalse);
    });

    test('withLease_WaitsUntilTheOtherHolderReleases', () async {
      final clock = FakeClock();
      final now = clock.now();
      await db.leasesDao.tryAcquire(
        name: LeaseNames.authRefresh,
        holder: 'other-isolate',
        now: now,
        expiresAt: now.add(const Duration(minutes: 5)),
      );
      final service = DriftLeaseService(db.leasesDao, clock, holder: 'me');

      final pending = service.withLease(
        LeaseNames.authRefresh,
        ttl: LeaseTimings.authRefreshTtl,
        wait: const Duration(seconds: 10),
        action: () async => 'mine',
      );
      await Future<void>.delayed(LeaseTimings.pollInterval * 2);
      await db.leasesDao.release(
        name: LeaseNames.authRefresh,
        holder: 'other-isolate',
      );

      expect(await pending, 'mine');
    });
  });
}
