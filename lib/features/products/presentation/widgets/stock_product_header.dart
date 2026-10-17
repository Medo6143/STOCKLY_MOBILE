import 'package:flutter/material.dart';
import 'package:stockly/core/text/initials.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/presentation/widgets/product_list_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The product at the top of the adjust and count forms: its badge, name
/// and current stock.
class StockProductHeader extends StatelessWidget {
  const new({required this.product, super.key});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return SurfaceCard(
      level: 2,
      radius: context.radii.xxl,
      child: Row(
        children: [
          LeadingBadge(
            text: initialsOf(product.name),
            icon: Icons.inventory_2_outlined,
            size: spacing.huge,
            tone: ProductListTile.toneOf(
              isLowStock: product.isLowStock,
              archived: product.isArchived,
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: textTheme.titleLarge),
                SizedBox(height: spacing.xxs),
                Text(
                  AppLocalizations.of(context).stockCurrentQuantity,
                  style: textTheme.bodyMedium?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
                QuantityText(
                  product.quantity,
                  unit: product.baseUnit.name,
                  isLow: product.isLowStock,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
