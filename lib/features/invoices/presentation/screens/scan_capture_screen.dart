import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_capture_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_capture_state.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Take the invoice photo, check it, queue it and try the first upload
/// (design §6.6, §11). States: loading = the camera, then "Saving…" and
/// "Uploading…"; empty = "Take a photo of the supplier invoice"; error =
/// camera denied or another device failure, with retry (image too large
/// and queue full show on the preview); data = the preview with "Use
/// photo" and "Retake". Upload failures never show here: the scan stays
/// in the queue.
class ScanCaptureScreen extends ConsumerWidget {
  const new({super.key});

  void _onChanged(BuildContext context, ScanCaptureState next) {
    switch (next.phase) {
      case ScanCapturePhase.uploaded:
        final invoiceId = next.invoiceId;
        if (invoiceId != null) {
          context.goNamed(
            RouteNames.invoiceDetail,
            pathParameters: {RoutePaths.invoiceIdParameter: invoiceId},
          );
        }
      case ScanCapturePhase.queued:
        showMessageSnackBar(
          context,
          AppLocalizations.of(context).scanCaptureSavedForLater,
        );
        context.goNamed(RouteNames.scanQueue);
      case ScanCapturePhase.idle ||
          ScanCapturePhase.picking ||
          ScanCapturePhase.preview ||
          ScanCapturePhase.saving ||
          ScanCapturePhase.uploading:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(scanCaptureProvider);
    final notifier = ref.read(scanCaptureProvider.notifier);
    ref.listen(scanCaptureProvider, (previous, next) {
      if (previous?.phase != next.phase) {
        _onChanged(context, next);
      }
    });
    final failure = state.failure;
    final value = switch (state.phase) {
      ScanCapturePhase.idle when failure != null =>
        AsyncError<ScanCaptureState>(failure, StackTrace.empty),
      ScanCapturePhase.idle ||
      ScanCapturePhase.preview => AsyncData<ScanCaptureState>(state),
      ScanCapturePhase.picking ||
      ScanCapturePhase.saving ||
      ScanCapturePhase.uploading ||
      ScanCapturePhase.uploaded ||
      ScanCapturePhase.queued => const AsyncLoading<ScanCaptureState>(),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanCaptureTitle)),
      body: AsyncStateView<ScanCaptureState>(
        value: value,
        loading: _BusyStep(phase: state.phase),
        isEmpty: (s) => s.imagePath == null,
        empty: _Start(notifier: notifier),
        onRetry: notifier.takePhoto,
        data: (context, s) => _Preview(state: s, notifier: notifier),
      ),
    );
  }
}

class _Start extends StatelessWidget {
  const new({required this.notifier});

  final ScanCaptureNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: EmptyState(
            title: l10n.scanCaptureEmptyTitle,
            body: l10n.scanCaptureEmptyBody,
            action: EmptyStateAction(
              label: l10n.scanCaptureTakePhoto,
              onPressed: notifier.takePhoto,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => notifier.takePhoto(fromGallery: true),
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(l10n.scanCaptureFromGallery),
        ),
        SizedBox(height: context.spacing.xl),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const new({required this.state, required this.notifier});

  final ScanCaptureState state;
  final ScanCaptureNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final failure = state.failure;
    return Padding(
      padding: EdgeInsetsDirectional.all(spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) ...[
            FormBanner(message: failureMessage(l10n, failure)),
            SizedBox(height: spacing.sm),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: context.radii.circular(context.radii.md),
              child: Image.file(
                File(state.imagePath!),
                fit: BoxFit.contain,
                semanticLabel: l10n.scanCapturePreviewLabel,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: spacing.huge,
                    color: context.colors.muted,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          FilledButton.icon(
            onPressed: notifier.usePhoto,
            icon: const Icon(Icons.check_rounded),
            label: Text(l10n.scanCaptureUsePhoto),
          ),
          SizedBox(height: spacing.xs),
          OutlinedButton.icon(
            onPressed: notifier.takePhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l10n.scanCaptureRetake),
          ),
        ],
      ),
    );
  }
}

/// The loading state: the step the capture is in.
class _BusyStep extends StatelessWidget {
  const new({required this.phase});

  final ScanCapturePhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = switch (phase) {
      ScanCapturePhase.saving => l10n.scanCaptureSaving,
      ScanCapturePhase.uploading ||
      ScanCapturePhase.uploaded ||
      ScanCapturePhase.queued => l10n.scanCaptureUploading,
      ScanCapturePhase.idle ||
      ScanCapturePhase.picking ||
      ScanCapturePhase.preview => l10n.commonLoading,
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(semanticsLabel: text),
          SizedBox(height: context.spacing.md),
          Text(text, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
