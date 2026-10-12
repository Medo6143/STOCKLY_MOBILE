import 'dart:async';

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
import 'package:stockly/core/widgets/paged_list_view.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/widgets/product_filter_chips.dart';
import 'package:stockly/features/products/presentation/widgets/product_list_tile.dart';
import 'package:stockly/features/products/presentation/widgets/product_search_field.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Search and browse products (P1, design §11): search, low-stock filter,
/// archived toggle, pages of 20, pull to refresh. States: loading = the
/// first page; empty = "No products yet" with add, or the empty search or
/// low-stock result; error = retry (a failed later page shows inline);
/// data = the paged list.
class ProductListScreen extends ConsumerStatefulWidget {
  const new({this.initialQuery = const ProductQuery(), super.key});

  /// The filters from the route (`lowStock=true`, `archived=true`).
  final ProductQuery initialQuery;

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final TextEditingController _search = TextEditingController();
  late ProductQuery _query = widget.initialQuery;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      context.durations.searchDebounce,
      () => setState(() => _query = _query.copyWith(search: value)),
    );
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() => _query = _query.copyWith(search: ''));
  }

  Future<void> _refresh() async {
    try {
      final provider = productListProvider(_query);
      ref.invalidate(provider);
      await ref.read(provider.future);
    } on Failure {
      // Shown by the snackbar listener below; the data stays.
    }
  }

  void _openProduct(ProductListItem item) => context.goNamed(
    RouteNames.productDetail,
    pathParameters: {RoutePaths.productIdParameter: item.id},
  );

  void _addProduct() => context.goNamed(RouteNames.productCreate);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final query = _query;
    final provider = productListProvider(query);
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.productsListTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addProduct,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.productsListAdd),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              spacing.md,
              spacing.xs,
              spacing.md,
              0,
            ),
            child: ProductSearchField(
              controller: _search,
              onChanged: _onSearchChanged,
              onClear: _clearSearch,
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ProductFilterChips(
                query: query,
                onChanged: (next) => setState(() => _query = next),
              ),
            ),
          ),
          Expanded(
            child: AsyncStateView<PagedState<ProductListItem>>(
              value: ref.watch(provider),
              isEmpty: (page) => page.items.isEmpty,
              empty: _empty(l10n, query),
              onRetry: () => ref.invalidate(provider),
              data: (context, page) => PagedListView<ProductListItem>(
                state: page,
                onLoadMore: () => ref.read(provider.notifier).loadMore(),
                onRefresh: _refresh,
                itemBuilder: (context, item) => ProductListTile(
                  item: item,
                  onTap: () => _openProduct(item),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations l10n, ProductQuery query) {
    final search = query.searchOrNull;
    if (search != null) {
      return EmptyState(
        title: l10n.productsListNoResultsTitle(search),
        body: l10n.productsListNoResultsBody,
      );
    }
    if (query.lowStock) {
      return EmptyState(
        title: l10n.productsListNoLowStockTitle,
        body: l10n.productsListNoLowStockBody,
      );
    }
    return EmptyState(
      title: l10n.productsListEmptyTitle,
      body: l10n.productsListEmptyBody,
      action: EmptyStateAction(
        label: l10n.productsListAdd,
        onPressed: _addProduct,
      ),
    );
  }
}
