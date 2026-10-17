import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One line of a recorded sale (design §11): quantity and unit, list price
/// and charged price with an override marker, line total and the stock
/// left after it.
class SaleItemTile extends StatelessWidget {
  const new({required this.item, super.key});

  final SaleItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final small = context.typo.numberSmall.copyWith(color: colors.muted);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        spacing.md,
        0,
        spacing.md,
        spacing.sm,
      ),
      child: SurfaceCard(
        padding: EdgeInsetsDirectional.symmetric(vertical: spacing.xxs),
        child: ListTile(
          contentPadding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.md,
          ),
          title: Text(item.productName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuantityText(item.quantity, unit: item.unitName),
              Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xxs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.salesUnitPriceLabel),
                  MoneyText(item.unitPrice, style: small),
                  if (item.priceOverridden) ...[
                    Text(l10n.salesListPriceLabel),
                    MoneyText(item.listUnitPrice, style: small),
                    Text(
                      l10n.salesPriceOverridden,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(color: colors.warning),
                    ),
                  ],
                ],
              ),
              Wrap(
                spacing: spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.salesBalanceAfter),
                  QuantityText(item.balanceAfter, style: small),
                ],
              ),
            ],
          ),
          trailing: MoneyText(item.lineTotal),
        ),
      ),
    );
  }
}
