import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/presentation/widgets/low_stock_badge.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One product row (design §11): name, sell price of the base unit, stock
/// in the base unit, low-stock badge and archived chip.
class ProductListTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final ProductListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
      title: Text(item.name),
      subtitle: Wrap(
        spacing: spacing.xs,
        runSpacing: spacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          MoneyText(
            item.baseUnit.sellPrice,
            style: context.typo.numberSmall.copyWith(
              color: context.colors.muted,
            ),
          ),
          if (item.isLowStock) LowStockBadge(label: l10n.productsLowStockBadge),
          if (item.isArchived)
            LowStockBadge(label: l10n.productsArchivedChip, muted: true),
        ],
      ),
      trailing: QuantityText(
        item.quantity,
        unit: item.baseUnit.name,
        isLow: item.isLowStock,
      ),
    );
  }
}
