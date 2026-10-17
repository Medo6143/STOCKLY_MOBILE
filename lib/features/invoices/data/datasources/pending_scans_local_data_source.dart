import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/daos/pending_scans_dao.dart';
import 'package:stockly/core/offline/tables/pending_scans.dart';

/// The queue rows (Drift) and their photos (files under
/// `<appSupportDir>/pending_scans/`). Throws [FileSystemException] for
/// file errors.
final class PendingScansLocalDataSource {
  const new(this._dao, this._directories);

  final PendingScansDao _dao;
  final AppDirectories _directories;

  Stream<List<PendingScan>> watchScans(String shopId) =>
      _dao.watchScansOfShop(shopId);

  Stream<int> watchCount(String shopId) => _dao.watchCountOfShop(shopId);

  Future<int> count(String shopId) => _dao.countOfShop(shopId);

  Future<PendingScan?> scan(String clientRequestId) =>
      _dao.scanById(clientRequestId);

  Future<List<PendingScan>> dueScans(
    String shopId, {
    required DateTime now,
    required bool force,
  }) => _dao.dueScans(shopId, now: now, force: force);

  Future<DateTime?> earliestNextAttempt(String shopId) =>
      _dao.earliestNextAttempt(shopId);

  /// Writes the photo first, then the row; a failed insert removes the
  /// photo again (design §6.1).
  Future<PendingScan> insert({
    required String clientRequestId,
    required String shopId,
    required String userId,
    required Uint8List jpeg,
    required DateTime now,
  }) async {
    final folder = Directory(
      '${_directories.supportDir}${Platform.pathSeparator}'
      '${ScanLimits.pendingScansFolder}',
    );
    await folder.create(recursive: true);
    final file = File(
      '${folder.path}${Platform.pathSeparator}'
      '$clientRequestId${ScanLimits.jpegExtension}',
    );
    await file.writeAsBytes(jpeg, flush: true);
    try {
      await _dao.insertScan(
        PendingScansCompanion.insert(
          clientRequestId: clientRequestId,
          shopId: shopId,
          userId: userId,
          imagePath: file.path,
          imageSizeBytes: jpeg.length,
          mimeType: ScanLimits.jpegMimeType,
          status: PendingScanStatus.queued,
          capturedAt: now,
          updatedAt: now,
        ),
      );
    } on Exception {
      await _deleteFile(file.path);
      rethrow;
    }
    return (await _dao.scanById(clientRequestId))!;
  }

  Future<void> update(String clientRequestId, PendingScansCompanion changes) =>
      _dao.updateScan(clientRequestId, changes);

  Future<void> resetStuckUploads({
    required DateTime cutoff,
    required DateTime now,
  }) => _dao.resetStuckUploads(cutoff: cutoff, now: now);

  Future<void> markQuotaExceeded(
    String shopId, {
    required DateTime now,
    required DateTime nextAttemptAt,
    required String errorCode,
  }) => _dao.markQuotaExceeded(
    shopId,
    now: now,
    nextAttemptAt: nextAttemptAt,
    errorCode: errorCode,
  );

  /// Deletes the row first, then its photo (design §6.4).
  Future<void> delete(PendingScan scan) async {
    await _dao.deleteScan(scan.clientRequestId);
    await _deleteFile(scan.imagePath);
  }

  bool photoExists(String path) => File(path).existsSync();

  /// Removes a temporary capture once it is queued.
  Future<void> deleteTemporary(String path) => _deleteFile(path);

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
