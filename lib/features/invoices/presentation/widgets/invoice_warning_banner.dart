import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_warning.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One extraction or review warning (contract `InvoiceWarning`).
class InvoiceWarningBanner extends StatelessWidget {
  const new({required this.warning, super.key});

  final InvoiceWarning warning;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: context.radii.circular(context.radii.md),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: colors.warning),
            SizedBox(width: spacing.xs),
            Expanded(
              child: Text(
                invoiceWarningLabel(AppLocalizations.of(context), warning),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
