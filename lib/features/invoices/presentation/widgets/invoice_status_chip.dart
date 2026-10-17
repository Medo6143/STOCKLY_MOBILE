import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The status of an invoice as a small pill in the status colors.
class InvoiceStatusChip extends StatelessWidget {
  const new({required this.status, super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final (background, foreground) = switch (status) {
      InvoiceStatus.processing => (colors.line, colors.muted),
      InvoiceStatus.needsReview => (colors.warningSoft, colors.warning),
      InvoiceStatus.confirmed => (colors.mintSoft, colors.ink),
      InvoiceStatus.failed => (colors.dangerSoft, colors.danger),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.radii.circular(context.radii.pill),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xxs / 2,
        ),
        child: Text(
          invoiceStatusLabel(AppLocalizations.of(context), status),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: foreground),
        ),
      ),
    );
  }
}
