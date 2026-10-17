import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The status filter of the invoice list: all, or one status (I2).
class InvoiceStatusFilterChips extends StatelessWidget {
  const new({required this.selected, required this.onChanged, super.key});

  /// `null` is "All".
  final InvoiceStatus? selected;
  final ValueChanged<InvoiceStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
      child: Row(
        children: [
          for (final status in <InvoiceStatus?>[null, ...InvoiceStatus.values])
            Padding(
              padding: EdgeInsetsDirectional.only(end: spacing.xs),
              child: ChoiceChip(
                label: Text(
                  status == null
                      ? l10n.invoicesFilterAll
                      : invoiceStatusLabel(l10n, status),
                ),
                selected: selected == status,
                onSelected: (_) => onChanged(status),
              ),
            ),
        ],
      ),
    );
  }
}
