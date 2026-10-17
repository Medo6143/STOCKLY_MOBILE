import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoices_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The product a line creates on confirm (contract I4 `newProduct`): name,
/// base unit and sell price. Its cost price is the line's unit price.
class NewProductForm extends StatelessWidget {
  const new({
    required this.name,
    required this.baseUnitName,
    required this.sellPrice,
    required this.issues,
    super.key,
  });

  final TextEditingController name;
  final TextEditingController baseUnitName;
  final TextEditingController sellPrice;
  final Map<InvoiceLineField, InvoiceFieldIssue> issues;

  String? _error(AppLocalizations l10n, InvoiceLineField field) {
    final issue = issues[field];
    return issue == null ? null : invoiceFieldIssueLabel(l10n, issue);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final gap = SizedBox(height: spacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.invoiceLineNewProductHeader,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: spacing.xxs),
        Text(
          l10n.invoiceLineNewProductHint,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.muted),
        ),
        gap,
        TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.invoiceLineNewProductName,
            errorText: _error(l10n, InvoiceLineField.newProductName),
          ),
        ),
        gap,
        TextField(
          controller: baseUnitName,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.invoiceLineNewProductBaseUnit,
            errorText: _error(l10n, InvoiceLineField.newProductBaseUnitName),
          ),
        ),
        gap,
        DecimalField(
          controller: sellPrice,
          label: l10n.invoiceLineNewProductSellPrice,
          enabled: true,
          errorText: _error(l10n, InvoiceLineField.newProductSellPrice),
        ),
      ],
    );
  }
}
