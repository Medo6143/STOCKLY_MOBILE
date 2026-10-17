import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';

/// The signed-in shop's sale whose outcome is unknown (design §6.8), or
/// `null`. The home shell reopens the quick sale for it.
final StreamProvider<PendingSale?> pendingSaleProvider =
    StreamProvider.autoDispose<PendingSale?>((ref) {
      final shopId = ref.watch(
        currentSessionProvider.select((s) => s?.shop.id),
      );
      return shopId == null
          ? Stream.value(null)
          : ref.watch(watchPendingSaleUseCaseProvider).call(shopId);
    });
