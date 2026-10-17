import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';

part 'scan_upload_outcome.freezed.dart';

/// What one upload attempt of a queued scan ended in (design §6.4).
@freezed
sealed class ScanUploadOutcome with _$ScanUploadOutcome {
  /// `202`: the server created the invoice; the row is gone.
  const factory created(String invoiceId) = ScanUploadCreated;

  /// `200`: an earlier attempt had reached the server; the row is gone.
  const factory alreadyUploaded(String invoiceId) = ScanAlreadyUploaded;

  /// The row stays in the queue in [status] and uploads later.
  const factory waiting(PendingScanStatus status) = ScanUploadWaiting;

  /// The row is not in the queue any more, or another isolate is uploading.
  const factory notQueued() = ScanNotQueued;
}

extension ScanUploadOutcomeX on ScanUploadOutcome {
  /// The invoice of a finished upload, else `null`.
  String? get invoiceId => switch (this) {
    ScanUploadCreated(:final invoiceId) ||
    ScanAlreadyUploaded(:final invoiceId) => invoiceId,
    ScanUploadWaiting() || ScanNotQueued() => null,
  };
}
