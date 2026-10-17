import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One sale of the history (design §11) as a card: when, how many lines,
/// total.
class SaleListTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final SaleListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          const LeadingBadge(icon: Icons.receipt_rounded),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ltrIsolate(DateFormatter.dateTime(item.createdAt, language)),
                  style: textTheme.titleMedium,
                ),
                Text(
                  l10n.salesItemCount(item.itemCount),
                  style: textTheme.bodySmall?.copyWith(
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          MoneyText(item.totalAmount),
        ],
      ),
    );
  }
}
