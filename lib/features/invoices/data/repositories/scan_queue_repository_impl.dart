import 'dart:async';

import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/media/image_compressor.dart';
import 'package:stockly/core/offline/background_sync.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/invoices/data/datasources/pending_scans_local_data_source.dart';
import 'package:stockly/features/invoices/data/models/invoice_mapper.dart';
import 'package:stockly/features/invoices/data/sync/scan_sync_service.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';
import 'package:stockly/features/invoices/domain/repositories/scan_queue_repository.dart';

final class ScanQueueRepositoryImpl implements ScanQueueRepository {
  new({
    required this._local,
    required this._sync,
    required this._compressor,
    required this._uuid,
    required this._background,
    required this._clock,
  });

  final PendingScansLocalDataSource _local;
  final ScanSyncService _sync;
  final ImageCompressor _compressor;
  final UuidGenerator _uuid;
  final BackgroundSyncRegistrar _background;
  final Clock _clock;

  static const Failure _storage = LocalFailure(LocalFailureReason.storage);

  @override
  Stream<List<PendingScan>> watchPending(String shopId) => _local
      .watchScans(shopId)
      .map((rows) => [for (final row in rows) row.toEntity()])
      .transform(_storageErrors());

  @override
  Stream<int> watchPendingCount(String shopId) =>
      _local.watchCount(shopId).transform(_storageErrors());

  /// A database error reaches the UI as a storage failure, never as a raw
  /// exception (repositories never throw to the UI).
  static StreamTransformer<T, T> _storageErrors<T>() =>
      StreamTransformer.fromHandlers(
        handleError: (error, stackTrace, sink) =>
            sink.addError(_storage, stackTrace),
      );

  @override
  Future<Result<PendingScan, Failure>> enqueue(
    CapturedImage image, {
    required String shopId,
    required String userId,
  }) async {
    try {
      if (await _local.count(shopId) >= ScanLimits.maxPendingScans) {
        return const Err(LocalFailure(LocalFailureReason.queueFull));
      }
      final compressed = await _compressor.compress(
        image.path,
        maxLongEdge: ScanLimits.maxLongEdgePx,
        jpegQuality: ScanLimits.jpegQuality,
      );
      switch (compressed) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final jpeg) when jpeg.length > ScanLimits.maxUploadBytes:
          return const Err(LocalFailure(LocalFailureReason.imageTooLarge));
        case Ok(value: final jpeg):
          // The id is created once, here, and stored before any upload
          // (ADR-0006): every retry sends this same id.
          final row = await _local.insert(
            clientRequestId: _uuid.v4(),
            shopId: shopId,
            userId: userId,
            jpeg: jpeg,
            now: _clock.now(),
          );
          await _cleanUp(image.path);
          return Ok(row.toEntity());
      }
    } on Exception {
      return const Err(_storage);
    }
  }

  /// The temporary capture is not needed once the JPEG is queued, and the
  /// background task may upload it if the app closes.
  Future<void> _cleanUp(String temporaryPath) async {
    try {
      await _local.deleteTemporary(temporaryPath);
      await _background.requestUpload();
    } on Exception {
      // Best-effort: the system clears temporary files, and the foreground
      // triggers still upload.
    }
  }

  @override
  Future<ScanUploadOutcome> uploadNow(String clientRequestId) =>
      _sync.uploadNow(clientRequestId);

  @override
  Future<DateTime?> runQueue({required bool force}) =>
      _sync.runOnce(force: force);

  @override
  Future<Result<void, Failure>> delete(String clientRequestId) async {
    try {
      final row = await _local.scan(clientRequestId);
      if (row != null) {
        await _local.delete(row);
      }
      return const Ok(null);
    } on Exception {
      return const Err(_storage);
    }
  }
}
