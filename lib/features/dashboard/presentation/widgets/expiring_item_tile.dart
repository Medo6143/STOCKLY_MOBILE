import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One expiring invoice line (design §11) as a card: product, expiry date,
/// batch, how much the line received and how much the product has now. An
/// [expired] line carries a danger chip. Tapping opens the invoice.
class ExpiringItemTile extends StatelessWidget {
  const new({
    required this.item,
    required this.onTap,
    this.expired = false,
    super.key,
  });

  final ExpiringItem item;
  final VoidCallback onTap;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final batch = item.batchNo;
    final small = context.typo.numberSmall.copyWith(color: colors.muted);
    final muted = textTheme.bodySmall?.copyWith(color: colors.muted);
    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadingBadge(
            icon: Icons.event_busy_rounded,
            tone: expired ? PillTone.danger : PillTone.warning,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: spacing.xs,
                  runSpacing: spacing.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(item.productName, style: textTheme.titleMedium),
                    if (expired)
                      StatusPill(
                        label: l10n.expiringExpiredChip,
                        tone: PillTone.danger,
                      ),
                  ],
                ),
                Text(
                  l10n.expiringExpiresOn(
                    ltrIsolate(DateFormatter.date(item.expiryDate, language)),
                  ),
                  style: muted,
                ),
                if (batch != null)
                  Text(l10n.expiringBatch(ltrIsolate(batch)), style: muted),
                Wrap(
                  spacing: spacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.expiringLineQuantity, style: muted),
                    QuantityText(item.lineQuantity, style: small),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: spacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(l10n.expiringInStock, style: muted),
              QuantityText(item.currentQuantity),
            ],
          ),
        ],
      ),
    );
  }
}
