import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/offline_banner.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';
import 'package:stockly/features/dashboard/presentation/widgets/summary_card.dart';
import 'package:stockly/features/dashboard/presentation/widgets/today_sales_card.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Today at a glance (D1, design §11), the home after sign-in. States:
/// loading = D1; empty = a new shop without products, "Add your first
/// product or scan an invoice" with both actions; error = retry; data =
/// the cards, each opening its list, and "updated at". Pull to refresh.
class DashboardScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      ref.invalidate(dashboardSummaryProvider);
      await ref.read(dashboardSummaryProvider.future);
    } on Failure {
      // Shown by the snackbar listener; the data stays.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    ref.listen(
      dashboardSummaryProvider,
      (_, next) => showRefreshFailure(context, next),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navDashboard)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => context.goNamed(RouteNames.quickSale),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(l10n.salesNewSale),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: AsyncStateView<DashboardSummary>(
              value: ref.watch(dashboardSummaryProvider),
              onRetry: () => ref.invalidate(dashboardSummaryProvider),
              isEmpty: (summary) => summary.isNewShop,
              empty: EmptyState(
                title: l10n.dashboardEmptyTitle,
                body: l10n.dashboardEmptyBody,
                action: EmptyStateAction(
                  label: l10n.dashboardAddProduct,
                  onPressed: () => context.goNamed(RouteNames.productCreate),
                ),
                secondaryAction: EmptyStateAction(
                  label: l10n.invoicesScanAction,
                  onPressed: () => context.goNamed(RouteNames.scanCapture),
                ),
              ),
              data: (context, summary) => RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: _SummaryList(summary: summary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryList extends StatelessWidget {
  const new({required this.summary});

  final DashboardSummary summary;

  void _lowStock(BuildContext context) => context.goNamed(
    RouteNames.products,
    queryParameters: {RoutePaths.lowStockParameter: RoutePaths.trueValue},
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final language = Localizations.localeOf(context).languageCode;
    final gap = SizedBox(width: spacing.sm, height: spacing.sm);
    Widget pair(Widget start, Widget end) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: start),
          gap,
          Expanded(child: end),
        ],
      ),
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.fromSTEB(
        spacing.md,
        spacing.md,
        spacing.md,
        spacing.huge * 2,
      ),
      children: [
        TodaySalesCard(
          sales: summary.todaySales,
          onTap: () => context.goNamed(RouteNames.sales),
        ),
        gap,
        pair(
          SummaryCard(
            icon: Icons.trending_down_rounded,
            label: l10n.dashboardLowStock,
            count: summary.lowStockCount,
            tone: SummaryTone.warning,
            onTap: () => _lowStock(context),
          ),
          SummaryCard(
            icon: Icons.remove_circle_outline_rounded,
            label: l10n.dashboardNegativeStock,
            count: summary.negativeStockCount,
            tone: SummaryTone.danger,
            onTap: () => _lowStock(context),
          ),
        ),
        gap,
        pair(
          SummaryCard(
            icon: Icons.event_busy_rounded,
            label: l10n.dashboardExpiringSoon,
            count: summary.expiringSoonCount,
            tone: SummaryTone.warning,
            onTap: () => context.goNamed(RouteNames.expiringSoon),
          ),
          SummaryCard(
            icon: Icons.fact_check_outlined,
            label: l10n.dashboardAwaitingReview,
            count: summary.invoicesAwaitingReview,
            tone: SummaryTone.warning,
            onTap: () => context.goNamed(
              RouteNames.invoices,
              queryParameters: {
                RoutePaths.statusParameter: RoutePaths.needsReviewValue,
              },
            ),
          ),
        ),
        gap,
        SummaryCard(
          icon: Icons.inventory_2_outlined,
          label: l10n.dashboardProducts,
          count: summary.productCount,
          onTap: () => context.goNamed(RouteNames.products),
        ),
        SizedBox(height: spacing.md),
        Text(
          l10n.dashboardUpdatedAt(
            ltrIsolate(DateFormatter.time(summary.generatedAt, language)),
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.muted),
        ),
      ],
    );
  }
}
