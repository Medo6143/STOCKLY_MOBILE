import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';

part 'scan_capture_state.freezed.dart';

/// The steps of the capture screen (design §6.6).
enum ScanCapturePhase {
  /// No photo yet: "Take a photo of the supplier invoice".
  idle,

  /// The camera or gallery is open.
  picking,

  /// The photo is shown with "Use photo" and "Retake".
  preview,

  /// Compressing and queueing.
  saving,

  /// The first upload attempt.
  uploading,

  /// Uploaded: [ScanCaptureState.invoiceId] is the new invoice.
  uploaded,

  /// Queued; it uploads later (offline, slow, or rejected for later).
  queued,
}

@freezed
abstract class ScanCaptureState with _$ScanCaptureState {
  const factory({
    @Default(ScanCapturePhase.idle) ScanCapturePhase phase,
    String? imagePath,
    String? invoiceId,
    Failure? failure,
  }) = _ScanCaptureState;
}
