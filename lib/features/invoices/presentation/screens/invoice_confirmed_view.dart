import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_header_summary.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_line_tile.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_warning_banner.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// A confirmed invoice, read-only (design §11): when it was confirmed, the
/// header and the lines.
class InvoiceConfirmedView extends StatelessWidget {
  const new({required this.invoice, super.key});

  final InvoiceDetail invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final language = Localizations.localeOf(context).languageCode;
    final confirmedAt = invoice.confirmedAt;
    return ListView(
      padding: EdgeInsetsDirectional.symmetric(vertical: spacing.md),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
          child: Row(
            children: [
              Icon(Icons.verified_outlined, color: colors.mint),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.invoiceConfirmedTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (confirmedAt != null)
                      Text(
                        l10n.invoiceConfirmedAt(
                          ltrIsolate(
                            DateFormatter.dateTime(confirmedAt, language),
                          ),
                        ),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsetsDirectional.all(spacing.md),
          child: InvoiceHeaderSummary(invoice: invoice),
        ),
        for (final warning in invoice.warnings)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              spacing.md,
              0,
              spacing.md,
              spacing.xs,
            ),
            child: InvoiceWarningBanner(warning: warning),
          ),
        Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
          child: Text(
            l10n.invoiceLinesHeader,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final item in invoice.items)
          InvoiceLineTile(line: InvoiceLineDraft.fromItem(item)),
      ],
    );
  }
}
