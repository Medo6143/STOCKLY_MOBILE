import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/paged_list_view.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/presentation/providers/payment_history_notifier.dart';
import 'package:stockly/features/billing/presentation/widgets/payment_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The shop's payments (B5, plans-payments brief), newest first, each with
/// its status pill; tapping one opens its status. States: loading = the
/// first page; empty = "No payments yet" with "See plans"; error = retry
/// (a failed later page shows inline); data = the pages.
class PaymentHistoryScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(paymentHistoryProvider);
      await ref.read(paymentHistoryProvider.future);
    } on Failure {
      // Shown by the snackbar listener; the data stays.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.listen(
      paymentHistoryProvider,
      (_, next) => showRefreshFailure(context, next),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.billingPaymentHistory)),
      body: AsyncStateView<PagedState<Payment>>(
        value: ref.watch(paymentHistoryProvider),
        isEmpty: (page) => page.items.isEmpty,
        empty: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: l10n.billingHistoryEmptyTitle,
          body: l10n.billingHistoryEmptyBody,
          action: EmptyStateAction(
            label: l10n.billingSeePlans,
            onPressed: () => context.goNamed(RouteNames.plans),
          ),
        ),
        onRetry: () => ref.invalidate(paymentHistoryProvider),
        data: (context, page) => PagedListView<Payment>(
          state: page,
          onLoadMore: () =>
              ref.read(paymentHistoryProvider.notifier).loadMore(),
          onRefresh: () => _refresh(ref),
          itemBuilder: (context, payment) => PaymentTile(
            payment: payment,
            onTap: () => context.pushNamed(
              RouteNames.paymentStatus,
              pathParameters: {RoutePaths.paymentIdParameter: payment.id},
            ),
          ),
        ),
      ),
    );
  }
}
