import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_status_chip.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One invoice row (design §11) as a card: a badge tinted by status,
/// supplier, number, date, item count, total, status and a warnings icon.
class InvoiceListTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final InvoiceListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final number = item.invoiceNumber;
    final date = item.invoiceDate;
    final total = item.totalAmount;
    final details = [
      if (number != null) ltrIsolate(number),
      if (date != null) ltrIsolate(DateFormatter.date(date, language)),
      l10n.invoicesItemCount(item.itemCount),
    ];
    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          LeadingBadge(
            icon: Icons.receipt_long_rounded,
            tone: InvoiceStatusChip.toneOf(item.status),
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.supplierName ?? l10n.invoicesUnknownSupplier,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    if (item.warnings.isNotEmpty)
                      Padding(
                        padding: EdgeInsetsDirectional.only(start: spacing.xxs),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: spacing.lg,
                          color: colors.warning,
                          semanticLabel: l10n.invoicesHasWarnings,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: spacing.xxs),
                Text(
                  details.join(' · '),
                  style: textTheme.bodySmall?.copyWith(color: colors.muted),
                ),
                SizedBox(height: spacing.xs),
                InvoiceStatusChip(status: item.status),
              ],
            ),
          ),
          if (total != null) ...[SizedBox(width: spacing.sm), MoneyText(total)],
        ],
      ),
    );
  }
}
