import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/media/image_compressor.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/offline/app_database.dart' as db;
import 'package:stockly/core/offline/backoff_policy.dart';
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/datasources/pending_scans_local_data_source.dart';
import 'package:stockly/features/invoices/data/repositories/scan_queue_repository_impl.dart';
import 'package:stockly/features/invoices/data/sync/scan_sync_service.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';

import '../../../helpers/fake_app.dart';
import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/products_doubles.dart' show errOf, okValue;
import '../../../helpers/scripted_adapter.dart';
import '../../../helpers/test_doubles.dart';

class _MockCompressor extends Mock implements ImageCompressor;

/// Design §6.1: compress, check the size, create the id once, store the
/// photo and the row before any upload.
void main() {
  late Directory support;
  late db.AppDatabase database;
  late _MockCompressor compressor;
  late CountingUuidGenerator uuid;
  late CountingSyncRegistrar registrar;
  late ScanQueueRepositoryImpl repository;
  late File capture;
  final shopId = storedSession().shop.id;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('stockly_queue');
    database = db.AppDatabase(NativeDatabase.memory());
    compressor = _MockCompressor();
    uuid = CountingUuidGenerator();
    registrar = CountingSyncRegistrar();
    capture = File('${support.path}/capture.jpg')..writeAsBytesSync([1, 2]);
    final local = PendingScansLocalDataSource(
      database.pendingScansDao,
      ResolvedAppDirectories(supportDir: support.path, tempDir: support.path),
    );
    repository = ScanQueueRepositoryImpl(
      local: local,
      sync: ScanSyncService(
        local: local,
        remote: InvoicesRemoteDataSource(
          buildBaseDio(
            config: fakeConfig,
            adapter: ScriptedAdapter((_) async => jsonBody(500, null)),
          ),
        ),
        leases: ImmediateLeaseService(),
        tokens: InMemoryTokenStorage(storedSession()),
        background: registrar,
        backoff: BackoffPolicy(Random(1)),
        clock: FakeClock(),
      ),
      compressor: compressor,
      uuid: uuid,
      background: registrar,
      clock: FakeClock(),
    );
    when(
      () => compressor.compress(
        any(),
        maxLongEdge: any(named: 'maxLongEdge'),
        jpegQuality: any(named: 'jpegQuality'),
      ),
    ).thenAnswer((_) async => Ok(Uint8List(64)));
  });

  tearDown(() async {
    await database.close();
    await support.delete(recursive: true);
  });

  Future<Result<PendingScan, Failure>> enqueue() => repository.enqueue(
    CapturedImage(path: capture.path),
    shopId: shopId,
    userId: 'user-1',
  );

  test('Enqueue_StoresPhotoAndRowWithANewId_BeforeAnyUpload', () async {
    final scan = okValue(await enqueue());

    expect(uuid.count, 1);
    expect(scan.status, PendingScanStatus.queued);
    expect(scan.attemptCount, 0);
    expect(scan.clientRequestId, hasLength(36));
    expect(File(scan.imagePath).readAsBytesSync(), hasLength(64));
    expect(scan.imagePath, contains(ScanLimits.pendingScansFolder));
    expect(capture.existsSync(), isFalse);
    expect(registrar.uploads, 1);
    verify(
      () => compressor.compress(
        capture.path,
        maxLongEdge: ScanLimits.maxLongEdgePx,
        jpegQuality: ScanLimits.jpegQuality,
      ),
    ).called(1);
  });

  test('TwoCaptures_TwoIds', () async {
    final a = okValue(await enqueue());
    capture.writeAsBytesSync([1]);
    final b = okValue(await enqueue());

    expect(a.clientRequestId, isNot(b.clientRequestId));
  });

  test('StillOver8Mb_ImageTooLarge_NothingQueued', () async {
    when(
      () => compressor.compress(
        any(),
        maxLongEdge: any(named: 'maxLongEdge'),
        jpegQuality: any(named: 'jpegQuality'),
      ),
    ).thenAnswer((_) async => Ok(Uint8List(ScanLimits.maxUploadBytes + 1)));

    final result = await enqueue();

    expect(
      (errOf(result) as LocalFailure).reason,
      LocalFailureReason.imageTooLarge,
    );
    expect(await database.pendingScansDao.countOfShop(shopId), 0);
    expect(uuid.count, 0);
  });

  test('CompressorFails_FailureReturned', () async {
    when(
      () => compressor.compress(
        any(),
        maxLongEdge: any(named: 'maxLongEdge'),
        jpegQuality: any(named: 'jpegQuality'),
      ),
    ).thenAnswer(
      (_) async => const Err(LocalFailure(LocalFailureReason.storage)),
    );

    expect(errOf(await enqueue()), isA<LocalFailure>());
  });

  test('FiftyQueued_QueueFull', () async {
    for (var i = 0; i < ScanLimits.maxPendingScans; i++) {
      capture.writeAsBytesSync([1]);
      okValue(await enqueue());
    }
    capture.writeAsBytesSync([1]);

    final result = await enqueue();

    expect(
      (errOf(result) as LocalFailure).reason,
      LocalFailureReason.queueFull,
    );
  });

  test('Delete_RemovesRowAndPhoto', () async {
    final scan = okValue(await enqueue());

    final result = await repository.delete(scan.clientRequestId);

    expect(result, isA<Ok<void, Failure>>());
    expect(File(scan.imagePath).existsSync(), isFalse);
    expect(await repository.watchPendingCount(shopId).first, 0);
  });

  test('Watch_MapsRowsAndCount', () async {
    final scan = okValue(await enqueue());

    final rows = await repository.watchPending(shopId).first;

    expect(rows.single, scan);
    expect(await repository.watchPendingCount(shopId).first, 1);
  });

  test('FileError_StorageFailure', () async {
    when(
      () => compressor.compress(
        any(),
        maxLongEdge: any(named: 'maxLongEdge'),
        jpegQuality: any(named: 'jpegQuality'),
      ),
    ).thenThrow(const FileSystemException('gone'));

    expect(
      (errOf(await enqueue()) as LocalFailure).reason,
      LocalFailureReason.storage,
    );
  });

  test('UploadNow_UsesTheSyncService', () async {
    final scan = okValue(await enqueue());

    final outcome = await repository.uploadNow(scan.clientRequestId);

    expect(outcome.invoiceId, isNull);
    expect(await repository.runQueue(force: false), isNotNull);
  });
}
