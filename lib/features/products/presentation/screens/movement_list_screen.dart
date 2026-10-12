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
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/presentation/providers/movement_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/widgets/movement_list_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The stock history of a product (P11, design §11), newest first, pages
/// of 20. States: loading = the first page; empty = "No movements yet";
/// error = `Product.NotFound` with back, or retry (a failed later page
/// shows inline); data = reason, signed change, balance after, note, time
/// and a link to the invoice or sale.
class MovementListScreen extends ConsumerWidget {
  const new({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = movementListProvider(productId);
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    final baseUnitName = ref
        .watch(productDetailProvider(productId))
        .value
        ?.baseUnit
        .name;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.movementsTitle)),
      body: AsyncStateView<PagedState<StockMovement>>(
        value: ref.watch(provider),
        isEmpty: (page) => page.items.isEmpty,
        empty: EmptyState(
          title: l10n.movementsEmptyTitle,
          body: l10n.movementsEmptyBody,
        ),
        onRetry: () => ref.invalidate(provider),
        data: (context, page) => PagedListView<StockMovement>(
          state: page,
          onLoadMore: () => ref.read(provider.notifier).loadMore(),
          onRefresh: () async {
            try {
              ref.invalidate(provider);
              await ref.read(provider.future);
            } on Failure {
              // Shown by the snackbar listener; the data stays.
            }
          },
          itemBuilder: (context, movement) => MovementListTile(
            movement: movement,
            baseUnitName: baseUnitName,
            onOpenInvoice: (id) => context.goNamed(
              RouteNames.invoiceDetail,
              pathParameters: {RoutePaths.invoiceIdParameter: id},
            ),
            onOpenSale: (id) => context.goNamed(
              RouteNames.saleDetail,
              pathParameters: {RoutePaths.saleIdParameter: id},
            ),
          ),
        ),
      ),
    );
  }
}
