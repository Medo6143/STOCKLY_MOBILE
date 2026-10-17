import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/animated_money_text.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Today's sales on the dashboard (design §11): total (counting up), number
/// of sales and how many had a changed price. It is the hero card that
/// overlaps the header. Tapping opens the sales list.
class TodaySalesCard extends StatelessWidget {
  const new({required this.sales, required this.onTap, super.key});

  final TodaySales sales;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodyMedium?.copyWith(color: colors.muted);
    return SurfaceCard(
      onTap: onTap,
      level: 2,
      radius: context.radii.xxl,
      padding: EdgeInsetsDirectional.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LeadingBadge(icon: Icons.point_of_sale_rounded),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  l10n.dashboardTodaySales,
                  style: textTheme.titleMedium,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
          SizedBox(height: spacing.md),
          AnimatedMoneyText(
            sales.total,
            style: context.typo.numberLarge.copyWith(color: colors.ink),
          ),
          SizedBox(height: spacing.xs),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.dashboardSalesCount(sales.count), style: muted),
              if (sales.overriddenSalesCount > 0)
                StatusPill(
                  label: l10n.dashboardOverriddenSales(
                    sales.overriddenSalesCount,
                  ),
                  tone: PillTone.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
