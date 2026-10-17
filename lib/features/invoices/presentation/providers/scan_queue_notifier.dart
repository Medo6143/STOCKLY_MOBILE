import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';
import 'package:stockly/features/invoices/presentation/providers/scan_queue_state.dart';

/// "Retry now", "Delete" and "Retake" on the queue screen (design §6.6).
final class ScanQueueNotifier extends Notifier<ScanQueueState> {
  @override
  ScanQueueState build() => const ScanQueueState();

  /// Uploads every waiting row now, ignoring `nextAttemptAt` (design §6.4).
  Future<void> retryNow() async {
    if (state.isRetrying) {
      return;
    }
    state = const ScanQueueState(isRetrying: true);
    await ref.read(syncPendingScansUseCaseProvider).call(force: true);
    if (ref.mounted) {
      state = const ScanQueueState();
    }
  }

  /// Removes the row and its photo. Returns `true` when it is gone.
  Future<bool> delete(String clientRequestId) async {
    final result = await ref
        .read(deletePendingScanUseCaseProvider)
        .call(clientRequestId);
    if (!ref.mounted) {
      return false;
    }
    switch (result) {
      case Ok():
        state = state.copyWith(failure: null);
        return true;
      case Err(:final failure):
        state = state.copyWith(failure: failure);
        return false;
    }
  }
}

final NotifierProvider<ScanQueueNotifier, ScanQueueState> scanQueueProvider =
    NotifierProvider.autoDispose<ScanQueueNotifier, ScanQueueState>(
      ScanQueueNotifier.new,
    );
