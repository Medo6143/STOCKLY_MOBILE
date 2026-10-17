import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_status_chip.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One invoice row (design §11): supplier, number, date, item count,
/// total, status and a warnings icon.
class InvoiceListTile extends StatelessWidget {
  const new({required this.item, required this.onTap, super.key});

  final InvoiceListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final language = Localizations.localeOf(context).languageCode;
    final number = item.invoiceNumber;
    final date = item.invoiceDate;
    final total = item.totalAmount;
    final details = [
      if (number != null) ltrIsolate(number),
      if (date != null) ltrIsolate(DateFormatter.date(date, language)),
      l10n.invoicesItemCount(item.itemCount),
    ];
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.supplierName ?? l10n.invoicesUnknownSupplier,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (item.warnings.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(start: spacing.xxs),
              child: Icon(
                Icons.warning_amber_rounded,
                color: colors.warning,
                semanticLabel: l10n.invoicesHasWarnings,
              ),
            ),
        ],
      ),
      subtitle: Wrap(
        spacing: spacing.xs,
        runSpacing: spacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          InvoiceStatusChip(status: item.status),
          Text(
            details.join(' · '),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.muted),
          ),
        ],
      ),
      trailing: total == null ? null : MoneyText(total),
    );
  }
}
