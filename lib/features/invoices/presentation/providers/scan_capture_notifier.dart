import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/invoices/domain/entities/captured_image.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/domain/entities/scan_upload_outcome.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_capture_state.dart';

/// Take a photo, preview it, queue it, then try the first upload (design
/// §6.1, §6.5, §6.6). Every capture gets a new `clientRequestId`, created
/// when it is queued.
final class ScanCaptureNotifier extends Notifier<ScanCaptureState> {
  @override
  ScanCaptureState build() => const ScanCaptureState();

  /// Opens the camera (or the gallery). A cancel keeps the current step.
  Future<void> takePhoto({bool fromGallery = false}) async {
    if (state.phase
        case ScanCapturePhase.picking ||
            ScanCapturePhase.saving ||
            ScanCapturePhase.uploading) {
      return;
    }
    final previous = state;
    state = previous.copyWith(phase: ScanCapturePhase.picking, failure: null);
    final result = await ref
        .read(takeInvoicePhotoUseCaseProvider)
        .call(fromGallery: fromGallery);
    if (!ref.mounted) {
      return;
    }
    state = switch (result) {
      Ok(value: final image?) => ScanCaptureState(
        phase: ScanCapturePhase.preview,
        imagePath: image.path,
      ),
      Ok() => previous.copyWith(failure: null),
      Err(:final failure) => previous.copyWith(failure: failure),
    };
  }

  /// Queues the previewed photo, then waits up to
  /// [SyncTimings.captureWait] for its first upload.
  Future<void> usePhoto() async {
    final path = state.imagePath;
    final session = ref.read(currentSessionProvider);
    if (state.phase != ScanCapturePhase.preview ||
        path == null ||
        session == null) {
      return;
    }
    state = state.copyWith(phase: ScanCapturePhase.saving, failure: null);
    final queued = await ref
        .read(captureInvoiceUseCaseProvider)
        .call(
          CapturedImage(path: path),
          shopId: session.shop.id,
          userId: session.user.id,
        );
    if (!ref.mounted) {
      return;
    }
    switch (queued) {
      case Err(:final failure):
        state = state.copyWith(
          phase: ScanCapturePhase.preview,
          failure: failure,
        );
      case Ok(value: final scan):
        state = state.copyWith(phase: ScanCapturePhase.uploading);
        final outcome = await ref
            .read(uploadPendingScanUseCaseProvider)
            .call(scan.clientRequestId)
            .timeout(
              SyncTimings.captureWait,
              onTimeout: () =>
                  const ScanUploadOutcome.waiting(PendingScanStatus.uploading),
            );
        if (!ref.mounted) {
          return;
        }
        final invoiceId = outcome.invoiceId;
        state = invoiceId == null
            ? state.copyWith(phase: ScanCapturePhase.queued)
            : state.copyWith(
                phase: ScanCapturePhase.uploaded,
                invoiceId: invoiceId,
              );
    }
  }
}

final NotifierProvider<ScanCaptureNotifier, ScanCaptureState>
scanCaptureProvider =
    NotifierProvider.autoDispose<ScanCaptureNotifier, ScanCaptureState>(
      ScanCaptureNotifier.new,
    );
