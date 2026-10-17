import 'package:flutter/material.dart';
import 'package:stockly/core/text/initials.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/hero_text.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/presentation/widgets/low_stock_badge.dart';
import 'package:stockly/features/products/presentation/widgets/product_hero_tags.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One product row (design §11) as a card: the initials badge and the name
/// (both fly to the detail), sell price of the base unit, stock in the
/// base unit, low-stock badge and archived chip.
class ProductListTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final ProductListItem item;
  final VoidCallback onTap;

  /// The badge tone of a product: warning when low, neutral when archived.
  static PillTone toneOf({required bool isLowStock, required bool archived}) =>
      archived
      ? PillTone.neutral
      : isLowStock
      ? PillTone.warning
      : PillTone.mint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          Hero(
            tag: productHeroTag(ProductHeroPart.badge, item.id),
            child: LeadingBadge(
              text: initialsOf(item.name),
              icon: Icons.inventory_2_outlined,
              tone: toneOf(
                isLowStock: item.isLowStock,
                archived: item.isArchived,
              ),
            ),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroText(
                  tag: productHeroTag(ProductHeroPart.name, item.id),
                  text: item.name,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: spacing.xxs),
                Wrap(
                  spacing: spacing.xs,
                  runSpacing: spacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText(
                      item.baseUnit.sellPrice,
                      style: context.typo.numberSmall.copyWith(
                        color: colors.muted,
                      ),
                    ),
                    if (item.isLowStock)
                      LowStockBadge(label: l10n.productsLowStockBadge),
                    if (item.isArchived)
                      LowStockBadge(
                        label: l10n.productsArchivedChip,
                        muted: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          QuantityText(
            item.quantity,
            unit: item.baseUnit.name,
            isLow: item.isLowStock,
          ),
        ],
      ),
    );
  }
}
