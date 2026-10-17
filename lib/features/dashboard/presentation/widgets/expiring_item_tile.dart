import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One expiring invoice line (design §11): product, expiry date, batch,
/// how much the line received and how much the product has now. An
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
    final language = Localizations.localeOf(context).languageCode;
    final batch = item.batchNo;
    final small = context.typo.numberSmall.copyWith(color: colors.muted);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
      leading: Icon(
        Icons.event_busy_rounded,
        color: expired ? colors.danger : colors.warning,
      ),
      title: Wrap(
        spacing: spacing.xs,
        runSpacing: spacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(item.productName),
          if (expired)
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.dangerSoft,
                borderRadius: BorderRadiusDirectional.circular(
                  context.radii.pill,
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacing.xs,
                  vertical: spacing.xxs,
                ),
                child: Text(
                  l10n.expiringExpiredChip,
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: colors.danger),
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.expiringExpiresOn(
              ltrIsolate(DateFormatter.date(item.expiryDate, language)),
            ),
          ),
          if (batch != null) Text(l10n.expiringBatch(ltrIsolate(batch))),
          Wrap(
            spacing: spacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.expiringLineQuantity),
              QuantityText(item.lineQuantity, style: small),
            ],
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            l10n.expiringInStock,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          QuantityText(item.currentQuantity),
        ],
      ),
    );
  }
}
