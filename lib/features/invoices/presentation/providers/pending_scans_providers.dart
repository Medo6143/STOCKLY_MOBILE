import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';

/// The shop whose queue the UI shows: rows of other shops are invisible
/// (design §6.7).
final Provider<String?> _currentShopIdProvider = Provider<String?>(
  (ref) => ref.watch(currentSessionProvider.select((s) => s?.shop.id)),
);

/// The queued scans of the signed-in shop, newest first (design §6.6).
final StreamProvider<List<PendingScan>> pendingScansProvider =
    StreamProvider.autoDispose<List<PendingScan>>((ref) {
      final shopId = ref.watch(_currentShopIdProvider);
      return shopId == null
          ? Stream.value(const [])
          : ref.watch(watchPendingScansUseCaseProvider).call(shopId);
    });

/// How many scans of the signed-in shop have not uploaded: the tab badge,
/// the list card and the sign-out warning (design §6.6, §6.7).
final pendingScanCountProvider = StreamProvider<int>((ref) {
  final shopId = ref.watch(_currentShopIdProvider);
  return shopId == null
      ? Stream.value(0)
      : ref.watch(watchPendingScanCountUseCaseProvider).call(shopId);
});
