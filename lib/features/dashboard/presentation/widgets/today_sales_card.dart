import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Today's sales on the dashboard (design §11): total, number of sales and
/// how many had a changed price. Tapping opens the sales list.
class TodaySalesCard extends StatelessWidget {
  const new({required this.sales, required this.onTap, super.key});

  final TodaySales sales;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: colors.muted);
    return Card(
      margin: EdgeInsetsDirectional.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.point_of_sale_rounded, color: colors.mint),
                  SizedBox(width: spacing.xs),
                  Expanded(
                    child: Text(
                      l10n.dashboardTodaySales,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.xs),
              MoneyText(
                sales.total,
                style: context.typo.numberLarge.copyWith(color: colors.ink),
              ),
              SizedBox(height: spacing.xxs),
              Text(l10n.dashboardSalesCount(sales.count), style: muted),
              if (sales.overriddenSalesCount > 0)
                Text(
                  l10n.dashboardOverriddenSales(sales.overriddenSalesCount),
                  style: muted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
