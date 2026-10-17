import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/empty_state.dart';
import 'package:stockly/core/widgets/offline_banner.dart';
import 'package:stockly/core/widgets/paged_list_view.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/sales/domain/entities/sale_date_range.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/presentation/providers/sale_list_notifier.dart';
import 'package:stockly/features/sales/presentation/widgets/sale_list_tile.dart';
import 'package:stockly/features/sales/presentation/widgets/sales_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Sales history (S2, design §11) with the "Today / 7 days / All" filter
/// and the new-sale button. States: loading = the first page; empty = "No
/// sales in this period" with new sale; error = retry (a failed later page
/// shows inline); data = the pages, newest first.
class SaleListScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SaleListScreen> createState() => _SaleListScreenState();
}

class _SaleListScreenState extends ConsumerState<SaleListScreen> {
  SaleDateRange _range = SaleDateRange.today;

  void _newSale() => context.goNamed(RouteNames.quickSale);

  Future<void> _refresh() async {
    try {
      final provider = saleListProvider(_range);
      ref.invalidate(provider);
      await ref.read(provider.future);
    } on Failure {
      // Shown by the snackbar listener; the data stays.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final provider = saleListProvider(_range);
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSales)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _newSale,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text(l10n.salesNewSale),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OfflineBanner(),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: spacing.md,
              vertical: spacing.xs,
            ),
            child: Wrap(
              spacing: spacing.xs,
              children: [
                for (final range in SaleDateRange.values)
                  ChoiceChip(
                    label: Text(saleDateRangeLabel(l10n, range)),
                    selected: range == _range,
                    onSelected: (_) => setState(() => _range = range),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncStateView<PagedState<SaleListItem>>(
              value: ref.watch(provider),
              isEmpty: (page) => page.items.isEmpty,
              empty: EmptyState(
                title: l10n.salesListEmptyTitle,
                body: l10n.salesListEmptyBody,
                action: EmptyStateAction(
                  label: l10n.salesNewSale,
                  onPressed: _newSale,
                ),
              ),
              onRetry: () => ref.invalidate(provider),
              data: (context, page) => PagedListView<SaleListItem>(
                state: page,
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: _refresh,
                itemBuilder: (context, item) => SaleListTile(
                  item: item,
                  onTap: () => context.goNamed(
                    RouteNames.saleDetail,
                    pathParameters: {RoutePaths.saleIdParameter: item.id},
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
