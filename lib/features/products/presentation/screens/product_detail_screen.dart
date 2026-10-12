import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/async_state_view.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/owner_only.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/core/widgets/snack_bars.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/widgets/low_stock_badge.dart';
import 'package:stockly/features/products/presentation/widgets/unit_list_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One product with its units and actions (P2, P5; design §11). States:
/// loading = while P2 runs; empty = not applicable (a product always has
/// its base unit); error = `Product.NotFound` (also another shop's
/// product) with back, or retry; data = header, stock, prices, units and
/// actions. Adjust, count and archive are for the Owner only.
class ProductDetailScreen extends ConsumerWidget {
  const new({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = productDetailProvider(productId);
    ref.listen(provider, (_, next) => showRefreshFailure(context, next));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.productsDetailTitle)),
      body: AsyncStateView<ProductDetail>(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (context, product) => RefreshIndicator(
          onRefresh: () async {
            try {
              ref.invalidate(provider);
              await ref.read(provider.future);
            } on Failure {
              // Shown by the snackbar listener; the data stays.
            }
          },
          child: _ProductDetailBody(product: product),
        ),
      ),
    );
  }
}

class _ProductDetailBody extends ConsumerWidget {
  const new({required this.product});

  final ProductDetail product;

  Map<String, String> get _productPath => {
    RoutePaths.productIdParameter: product.id,
  };

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.productsArchiveDialogTitle),
        content: Text(l10n.productsArchiveDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.productsDetailArchive),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final failure = await ref
        .read(productDetailProvider(product.id).notifier)
        .archive();
    if (!context.mounted) {
      return;
    }
    if (failure == null) {
      showMessageSnackBar(context, l10n.productsArchived);
    } else {
      showFailureSnackBar(context, failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final base = product.baseUnit;
    final barcode = product.barcode;
    final category = product.category;
    final editable = !product.isArchived;
    Widget fact(String label, Widget value) => Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: spacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: colors.muted),
            ),
          ),
          value,
        ],
      ),
    );
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.all(spacing.md),
      children: [
        Text(product.name, style: textTheme.headlineMedium),
        SizedBox(height: spacing.xs),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xxs,
          children: [
            if (product.isLowStock)
              LowStockBadge(label: l10n.productsLowStockBadge),
            if (product.isArchived)
              LowStockBadge(label: l10n.productsArchivedChip, muted: true),
          ],
        ),
        if (product.isArchived) ...[
          SizedBox(height: spacing.xs),
          Text(
            l10n.productsDetailArchivedNotice,
            style: textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
        ],
        SizedBox(height: spacing.md),
        Text(
          l10n.productsDetailQuantity,
          style: textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
        QuantityText(
          product.quantity,
          unit: base.name,
          isLow: product.isLowStock,
          style: context.typo.numberLarge,
        ),
        SizedBox(height: spacing.md),
        fact(l10n.productsDetailSellPrice, MoneyText(base.sellPrice)),
        fact(l10n.productsDetailCostPrice, MoneyText(product.costPrice)),
        fact(
          l10n.productsDetailThreshold,
          QuantityText(product.lowStockThreshold, unit: base.name),
        ),
        if (category != null) fact(l10n.productsDetailCategory, Text(category)),
        if (barcode != null)
          fact(
            l10n.productsDetailBarcode,
            Text(ltrIsolate(barcode), style: context.typo.code),
          ),
        SizedBox(height: spacing.md),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [
            if (editable)
              OutlinedButton.icon(
                onPressed: () => context.goNamed(
                  RouteNames.productEdit,
                  pathParameters: _productPath,
                ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.productsDetailEdit),
              ),
            OutlinedButton.icon(
              onPressed: () => context.goNamed(
                RouteNames.movements,
                pathParameters: _productPath,
              ),
              icon: const Icon(Icons.history_rounded),
              label: Text(l10n.productsDetailMovements),
            ),
            OwnerOnly(
              child: OutlinedButton.icon(
                onPressed: () => context.goNamed(
                  RouteNames.stockAdjust,
                  pathParameters: _productPath,
                ),
                icon: const Icon(Icons.tune_rounded),
                label: Text(l10n.productsDetailAdjust),
              ),
            ),
            OwnerOnly(
              child: OutlinedButton.icon(
                onPressed: () => context.goNamed(
                  RouteNames.stockCount,
                  pathParameters: _productPath,
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(l10n.productsDetailCount),
              ),
            ),
            if (editable)
              OwnerOnly(
                child: OutlinedButton.icon(
                  onPressed: () => _archive(context, ref),
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(l10n.productsDetailArchive),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.productsDetailUnitsHeader,
                style: textTheme.titleLarge,
              ),
            ),
            if (editable)
              TextButton.icon(
                onPressed: () => context.goNamed(
                  RouteNames.unitCreate,
                  pathParameters: _productPath,
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.productsDetailAddUnit),
              ),
          ],
        ),
        for (final unit in product.units)
          UnitListTile(
            unit: unit,
            baseUnitName: base.name,
            onTap: editable
                ? () => context.goNamed(
                    RouteNames.unitEdit,
                    pathParameters: {
                      ..._productPath,
                      RoutePaths.unitIdParameter: unit.id,
                    },
                  )
                : null,
          ),
      ],
    );
  }
}
