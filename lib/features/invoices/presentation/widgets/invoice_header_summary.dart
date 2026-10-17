import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The header of an invoice, read-only: supplier, number, date, the
/// invoice total and the sum of the lines.
class InvoiceHeaderSummary extends StatelessWidget {
  const new({required this.invoice, super.key});

  final InvoiceDetail invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: context.colors.muted);
    final number = invoice.invoiceNumber;
    final date = invoice.invoiceDate;
    final total = invoice.totalAmount;
    final computed = invoice.computedTotal;
    Widget row(String label, Widget value) => Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: context.spacing.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: muted)),
          value,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          l10n.invoiceSupplierLabel,
          Text(invoice.supplierName ?? l10n.invoicesUnknownSupplier),
        ),
        if (number != null)
          row(l10n.invoiceNumberLabel, Text(ltrIsolate(number))),
        if (date != null)
          row(
            l10n.invoiceDateLabel,
            Text(ltrIsolate(DateFormatter.date(date, language))),
          ),
        if (total != null) row(l10n.invoiceTotalLabel, MoneyText(total)),
        if (computed != null)
          row(l10n.invoiceComputedTotalLabel, MoneyText(computed)),
      ],
    );
  }
}
