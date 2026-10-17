import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The AI could not read the invoice (design §11): the server's reason and
/// "Scan again", which captures a new photo with a new `clientRequestId`.
class InvoiceFailedView extends StatelessWidget {
  const new({required this.invoice, required this.onScanAgain, super.key});

  final InvoiceDetail invoice;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final reason = invoice.failureReason;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: spacing.huge,
              color: colors.danger,
            ),
            SizedBox(height: spacing.md),
            Text(
              l10n.invoiceFailedTitle,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xs),
            Text(
              reason == null
                  ? l10n.invoiceFailedBody
                  : l10n.invoiceFailedReason(reason),
              style: textTheme.bodyMedium?.copyWith(color: colors.muted),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xl),
            FilledButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l10n.invoiceFailedScanAgain),
            ),
          ],
        ),
      ),
    );
  }
}
