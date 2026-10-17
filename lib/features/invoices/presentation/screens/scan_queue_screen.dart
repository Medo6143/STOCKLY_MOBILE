import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/platform/connectivity.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/offline_banner.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_queue_notifier.dart';
import 'package:stockly/features/invoices/presentation/widgets/pending_scan_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The scans waiting to upload (design §6.6, §11). States: loading = the
/// first database read; empty = "All scans uploaded"; error = a local
/// storage error with retry; data = one tile per scan with its status and
/// actions, "Retry now", and the offline banner.
class ScanQueueScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PendingScan scan,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.scanQueueDeleteTitle),
        content: Text(l10n.scanQueueDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(scanQueueProvider.notifier).delete(scan.clientRequestId);
    }
  }

  Future<void> _retake(
    BuildContext context,
    WidgetRef ref,
    PendingScan scan,
  ) async {
    final deleted = await ref
        .read(scanQueueProvider.notifier)
        .delete(scan.clientRequestId);
    if (deleted && context.mounted) {
      context.goNamed(RouteNames.scanCapture);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final queue = ref.watch(scanQueueProvider);
    final online = ref.watch(connectivityProvider).value ?? true;
    final now = ref.watch(clockProvider).now();
    ref.listen(scanQueueProvider, (previous, next) {
      final failure = next.failure;
      if (failure != null && failure != previous?.failure) {
        showFailureSnackBar(context, failure);
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanQueueTitle),
        actions: [
          TextButton.icon(
            onPressed: queue.isRetrying
                ? null
                : ref.read(scanQueueProvider.notifier).retryNow,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.scanQueueRetryNow),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (queue.isRetrying) const LinearProgressIndicator(),
          Expanded(
            child: AsyncStateView<List<PendingScan>>(
              value: ref.watch(pendingScansProvider),
              isEmpty: (scans) => scans.isEmpty,
              empty: EmptyState(
                title: l10n.scanQueueEmptyTitle,
                body: l10n.scanQueueEmptyBody,
              ),
              onRetry: () => ref.invalidate(pendingScansProvider),
              data: (context, scans) => ListView.builder(
                itemCount: scans.length,
                itemBuilder: (context, index) => PendingScanTile(
                  scan: scans[index],
                  online: online,
                  now: now,
                  onDelete: () => _delete(context, ref, scans[index]),
                  onRetake: () => _retake(context, ref, scans[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
