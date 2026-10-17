import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_scan.freezed.dart';

/// Upload state of a queued invoice photo (design §6.3).
enum PendingScanStatus {
  queued,
  uploading,
  waitingRetry,
  rateLimited,
  quotaExceeded,
  failedPermanent,
}

/// One invoice photo waiting for upload (design §6.2). [clientRequestId]
/// is created once at capture and sent on every attempt (ADR-0006).
@freezed
abstract class PendingScan with _$PendingScan {
  const factory({
    required String clientRequestId,
    required PendingScanStatus status,
    required String imagePath,
    required int imageSizeBytes,
    required int attemptCount,
    required DateTime? nextAttemptAt,
    required String? lastErrorCode,
    required DateTime capturedAt,
  }) = _PendingScan;
}
