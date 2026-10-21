import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/offline/app_database.dart' as db;
import 'package:stockly/core/offline/backoff_policy.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart' as db;
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/datasources/pending_scans_local_data_source.dart';
import 'package:stockly/features/invoices/data/sync/scan_sync_service.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';

import '../../../helpers/fake_app.dart';
import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/scripted_adapter.dart';
import '../../../helpers/test_doubles.dart';

/// No jitter: `nextDouble` is the middle of the range.
final class _MiddleRandom implements Random {
  @override
  double nextDouble() => 0.5;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

const String _otherShop = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d0b';

Map<String, Object?> _listItem(String status) => {
  'id': invoiceId,
  'status': status,
  'supplierName': null,
  'invoiceNumber': null,
  'invoiceDate': null,
  'totalAmount': null,
  'itemCount': 0,
  'warnings': <String>[],
  'createdAt': '2026-10-12T07:00:00Z',
};

/// Design §6.4 and §13.1 "Offline queue": every response moves the row
/// along the state machine, always with the stored `clientRequestId`.
void main() {
  late Directory support;
  late db.AppDatabase database;
  late PendingScansLocalDataSource local;
  late ScriptedAdapter adapter;
  late FakeClock clock;
  late CountingSyncRegistrar registrar;
  late InMemoryTokenStorage tokens;
  late ScanSyncService service;
  final shopId = storedSession().shop.id;
  var serial = 0;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('stockly_sync');
    database = db.AppDatabase(NativeDatabase.memory());
    local = PendingScansLocalDataSource(
      database.pendingScansDao,
      ResolvedAppDirectories(supportDir: support.path, tempDir: support.path),
    );
    adapter = ScriptedAdapter(
      (_) async => jsonBody(202, _listItem('Processing')),
    );
    clock = FakeClock();
    registrar = CountingSyncRegistrar();
    tokens = InMemoryTokenStorage(storedSession());
    service = ScanSyncService(
      local: local,
      remote: InvoicesRemoteDataSource(
        buildBaseDio(config: fakeConfig, adapter: adapter),
      ),
      leases: ImmediateLeaseService(),
      tokens: tokens,
      background: registrar,
      backoff: BackoffPolicy(_MiddleRandom()),
      clock: clock,
    );
  });

  tearDown(() async {
    await database.close();
    await support.delete(recursive: true);
  });

  Future<db.PendingScan> queue({
    String? shop,
    Duration capturedAfter = Duration.zero,
  }) {
    serial++;
    return local.insert(
      clientRequestId: '0192f0a0-6c1e-7b3a-9d2e-${'$serial'.padLeft(12, '0')}',
      shopId: shop ?? shopId,
      userId: 'user-1',
      jpeg: Uint8List(32),
      now: clock.now().add(capturedAfter),
    );
  }

  Future<db.PendingScan?> row(db.PendingScan scan) =>
      database.pendingScansDao.scanById(scan.clientRequestId);

  String sentId(RequestOptions request) => (request.data! as FormData).fields
      .firstWhere((f) => f.key == 'clientRequestId')
      .value;

  void respond(int status, String code, {Map<String, List<String>>? headers}) =>
      adapter.respond = (_) async =>
          problemBody(status, code, headers: headers ?? const {});

  test('202_DeletesRowAndPhoto_Created', () async {
    final scan = await queue();

    final outcome = await service.uploadNow(scan.clientRequestId);

    expect(outcome, const ScanUploadOutcome.created(invoiceId));
    expect(await row(scan), isNull);
    expect(File(scan.imagePath).existsSync(), isFalse);
    expect(sentId(adapter.requests.single), scan.clientRequestId);
    final image = (adapter.requests.single.data! as FormData).files.single;
    expect(image.value.contentType?.mimeType, 'image/jpeg');
    expect(image.value.filename, '${scan.clientRequestId}.jpg');
  });

  test('200Repeat_DeletesRow_AlreadyUploaded', () async {
    final scan = await queue();
    adapter.respond = (_) async => jsonBody(200, _listItem('NeedsReview'));

    final outcome = await service.uploadNow(scan.clientRequestId);

    expect(outcome, const ScanUploadOutcome.alreadyUploaded(invoiceId));
    expect(await row(scan), isNull);
  });

  for (final (status, code) in [
    (400, 'Invoice.ImageRequired'),
    (400, 'Invoice.UnsupportedImageType'),
    (400, 'Validation.Failed'),
    (413, 'Invoice.ImageTooLarge'),
  ]) {
    test('${status}_${code}_FailedPermanent', () async {
      final scan = await queue();
      respond(status, code);

      final outcome = await service.uploadNow(scan.clientRequestId);

      final stored = (await row(scan))!;
      expect(stored.status, db.PendingScanStatus.failedPermanent);
      expect(stored.lastErrorCode, code);
      expect(stored.attemptCount, 1);
      expect(
        outcome,
        const ScanUploadOutcome.waiting(PendingScanStatus.failedPermanent),
      );
      expect(File(scan.imagePath).existsSync(), isTrue);
      expect(registrar.uploads, 0);
    });
  }

  test('429RateLimited_UsesRetryAfter_AndStopsTheRun', () async {
    final first = await queue();
    final second = await queue(capturedAfter: const Duration(seconds: 1));
    respond(
      429,
      'Scan.RateLimited',
      headers: {
        HttpHeaderNames.retryAfter: ['42'],
      },
    );

    final next = await service.runOnce(force: false);

    final stored = (await row(first))!;
    expect(stored.status, db.PendingScanStatus.rateLimited);
    expect(stored.nextAttemptAt, clock.now().add(const Duration(seconds: 42)));
    expect((await row(second))!.status, db.PendingScanStatus.queued);
    expect(adapter.requests, hasLength(1));
    expect(next, stored.nextAttemptAt);
  });

  test('429Quota_EveryRowWaitsUntilRetryAfter', () async {
    final first = await queue();
    final second = await queue(capturedAfter: const Duration(seconds: 1));
    respond(
      429,
      'Scan.DailyQuotaExceeded',
      headers: {
        HttpHeaderNames.retryAfter: ['3600'],
      },
    );

    await service.runOnce(force: false);

    for (final scan in [first, second]) {
      final stored = (await row(scan))!;
      expect(stored.status, db.PendingScanStatus.quotaExceeded);
      expect(stored.nextAttemptAt, clock.now().add(const Duration(hours: 1)));
    }
    expect(adapter.requests, hasLength(1));
  });

  test('429QuotaWithoutRetryAfter_HourlyRecheck', () async {
    final scan = await queue();
    respond(429, 'Scan.DailyQuotaExceeded');

    await service.uploadNow(scan.clientRequestId);

    expect(
      (await row(scan))!.nextAttemptAt,
      clock.now().add(const Duration(hours: 1)),
    );
  });

  test('401SessionEnded_BackToQueued_StopsTheRun', () async {
    final first = await queue();
    final second = await queue(capturedAfter: const Duration(seconds: 1));
    respond(401, 'Auth.Unauthenticated');

    await service.runOnce(force: false);

    expect((await row(first))!.status, db.PendingScanStatus.queued);
    expect((await row(second))!.attemptCount, 0);
  });

  test('403ShopSuspended_BackToQueued', () async {
    final scan = await queue();
    respond(403, 'Shop.Suspended');

    await service.uploadNow(scan.clientRequestId);

    expect((await row(scan))!.status, db.PendingScanStatus.queued);
  });

  for (final (name, status, code) in [
    ('500', 500, 'Server.Unexpected'),
    ('409', 409, 'Invoice.NotEditable'),
    ('502Html', 502, null),
  ]) {
    test('${name}_WaitingRetryWithBackoff', () async {
      final scan = await queue();
      adapter.respond = (_) async => code == null
          ? ResponseBody.fromString('<html>bad gateway</html>', status)
          : problemBody(status, code);

      await service.uploadNow(scan.clientRequestId);

      final stored = (await row(scan))!;
      expect(stored.status, db.PendingScanStatus.waitingRetry);
      expect(
        stored.nextAttemptAt,
        clock.now().add(const Duration(seconds: 30)),
      );
      expect(registrar.uploads, 1);
    });
  }

  test('Offline_WaitingRetry_BackoffGrows_SameIdEveryAttempt', () async {
    final scan = await queue();
    adapter.respond = (options) async => throw DioException.connectionError(
      requestOptions: options,
      reason: 'offline',
    );

    await service.runOnce(force: true);
    await service.runOnce(force: true);
    await service.runOnce(force: true);

    final stored = (await row(scan))!;
    expect(stored.status, db.PendingScanStatus.waitingRetry);
    expect(stored.attemptCount, 3);
    expect(stored.nextAttemptAt, clock.now().add(const Duration(seconds: 120)));
    expect(adapter.requests.map(sentId).toSet(), {scan.clientRequestId});
  });

  test('NotDueYet_SkippedUnlessForced', () async {
    final scan = await queue();
    respond(500, 'Server.Unexpected');
    await service.uploadNow(scan.clientRequestId);
    adapter.respond = (_) async => jsonBody(202, _listItem('Processing'));

    final next = await service.runOnce(force: false);
    expect(next, isNotNull);
    expect(await row(scan), isNotNull);

    await service.runOnce(force: true);
    expect(await row(scan), isNull);
  });

  test('DueAfterBackoff_Uploads', () async {
    final scan = await queue();
    respond(500, 'Server.Unexpected');
    await service.uploadNow(scan.clientRequestId);
    adapter.respond = (_) async => jsonBody(202, _listItem('Processing'));
    clock.advance(const Duration(seconds: 30));

    await service.runOnce(force: false);

    expect(await row(scan), isNull);
  });

  test('OtherShopsRows_NeverUploaded', () async {
    final other = await queue(shop: _otherShop);

    await service.runOnce(force: true);
    final outcome = await service.uploadNow(other.clientRequestId);

    expect(adapter.requests, isEmpty);
    expect(outcome, const ScanUploadOutcome.notQueued());
  });

  test('SignedIntoAnotherShopMidRun_RestOfTheQueueNotUploaded', () async {
    final first = await queue();
    final second = await queue(capturedAfter: const Duration(seconds: 1));
    adapter.respond = (_) async {
      // Signed out and into another shop while the first upload was out.
      tokens.session = storedSession(shopId: otherShopId);
      return jsonBody(202, _listItem('Processing'));
    };

    await service.runOnce(force: true);

    expect(adapter.requests.map(sentId), [first.clientRequestId]);
    expect((await row(second))?.status, db.PendingScanStatus.queued);
  });

  test('Upload_CarriesTheShopOfItsRow', () async {
    await queue();

    await service.runOnce(force: true);

    // The auth interceptor refuses to send it with another shop's token.
    expect(adapter.requests.single.extra[RequestExtras.shopId], shopId);
  });

  test('NoSession_DoesNothing', () async {
    await queue();
    tokens.session = null;

    expect(await service.runOnce(force: true), isNull);
    expect(adapter.requests, isEmpty);
  });

  test('StuckUploading_ResetToQueuedAndUploaded', () async {
    final scan = await queue();
    await database.pendingScansDao.updateScan(
      scan.clientRequestId,
      const db.PendingScansCompanion(
        status: Value(db.PendingScanStatus.uploading),
      ),
    );
    clock.advance(const Duration(minutes: 3));

    await service.runOnce(force: false);

    expect(await row(scan), isNull);
    expect(sentId(adapter.requests.single), scan.clientRequestId);
  });

  test('RecentUploading_LeftAlone', () async {
    final scan = await queue();
    await database.pendingScansDao.updateScan(
      scan.clientRequestId,
      const db.PendingScansCompanion(
        status: Value(db.PendingScanStatus.uploading),
      ),
    );

    await service.runOnce(force: true);

    expect(adapter.requests, isEmpty);
    expect((await row(scan))!.status, db.PendingScanStatus.uploading);
  });

  test('PhotoMissing_FailedPermanentStorage', () async {
    final scan = await queue();
    File(scan.imagePath).deleteSync();

    await service.uploadNow(scan.clientRequestId);

    final stored = (await row(scan))!;
    expect(stored.status, db.PendingScanStatus.failedPermanent);
    expect(stored.lastErrorCode, 'storage');
    expect(adapter.requests, isEmpty);
  });

  test('FailedPermanent_NotRetried', () async {
    final scan = await queue();
    respond(413, 'Invoice.ImageTooLarge');
    await service.uploadNow(scan.clientRequestId);

    await service.runOnce(force: true);
    final again = await service.uploadNow(scan.clientRequestId);

    expect(adapter.requests, hasLength(1));
    expect(again, const ScanUploadOutcome.notQueued());
  });

  test('BusyLease_NotQueuedOutcome', () async {
    final scan = await queue();
    final busy = ScanSyncService(
      local: local,
      remote: InvoicesRemoteDataSource(
        buildBaseDio(config: fakeConfig, adapter: adapter),
      ),
      leases: _BusyLease(),
      tokens: tokens,
      background: registrar,
      backoff: BackoffPolicy(_MiddleRandom()),
      clock: clock,
    );

    final outcome = await busy.uploadNow(scan.clientRequestId);

    expect(outcome, const ScanUploadOutcome.notQueued());
    expect(adapter.requests, isEmpty);
  });
}

/// Another isolate holds the lease.
final class _BusyLease implements LeaseService {
  @override
  Future<T?> withLease<T>(
    String name, {
    required Duration ttl,
    required Duration wait,
    required Future<T> Function() action,
  }) async => null;
}
