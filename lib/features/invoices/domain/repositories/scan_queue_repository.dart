import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';

/// The offline scan queue (design §6). A photo is always queued first; the
/// upload is a separate step, in the foreground or the background.
abstract interface class ScanQueueRepository {
  /// Rows of [shopId], newest capture first, on every change.
  Stream<List<PendingScan>> watchPending(String shopId);

  /// How many rows of [shopId] have not uploaded, on every change.
  Stream<int> watchPendingCount(String shopId);

  /// Compresses [image], creates its `clientRequestId` and stores the row
  /// with the photo before any upload (design §6.1).
  Future<Result<PendingScan, Failure>> enqueue(
    CapturedImage image, {
    required String shopId,
    required String userId,
  });

  /// One upload attempt of the row [clientRequestId] now (I1).
  Future<ScanUploadOutcome> uploadNow(String clientRequestId);

  /// Uploads the due rows of the signed-in shop one by one; [force]
  /// ignores `nextAttemptAt`. Returns the earliest `nextAttemptAt` left.
  Future<DateTime?> runQueue({required bool force});

  /// Removes the row and its photo.
  Future<Result<void, Failure>> delete(String clientRequestId);
}
