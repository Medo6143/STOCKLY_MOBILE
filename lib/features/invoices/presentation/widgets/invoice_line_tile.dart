import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One line of an invoice (design §11): raw name, chosen product and unit
/// (or the new product), quantity × unit price, the server's line total,
/// expiry, batch and match confidence. [hasError] highlights a line that
/// needs a product; [messages] are the server's field messages.
class InvoiceLineTile extends StatelessWidget {
  const new({
    required this.line,
    this.hasError = false,
    this.messages = const [],
    this.onTap,
    this.onRemove,
    super.key,
  });

  final InvoiceLineDraft line;
  final bool hasError;
  final List<String> messages;

  /// `null` for a read-only line.
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final language = Localizations.localeOf(context).languageCode;
    final expiry = line.expiryDate;
    final batch = line.batchNo;
    final confidence = line.matchConfidence;
    final lineTotal = line.lineTotal;
    final choice = line.choice;
    final unresolved = choice is UnresolvedChoice;
    final product = switch (choice) {
      ExistingProductChoice(:final productName, :final unitName) =>
        l10n.quantityWithUnit(productName, unitName),
      NewProductChoice(:final product) => l10n.invoiceLineNewProduct(
        product.name,
      ),
      UnresolvedChoice() => l10n.invoiceLineUnresolved,
    };
    final details = [
      if (expiry != null)
        l10n.invoiceLineExpiry(
          ltrIsolate(DateFormatter.date(expiry, language)),
        ),
      if (batch != null) l10n.invoiceLineBatch(ltrIsolate(batch)),
      if (confidence != null)
        l10n.invoiceLineConfidence(
          ltrIsolate(DecimalFormatter.formatConfidencePercent(confidence)),
        ),
    ];
    final danger = hasError || messages.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(bottom: BorderSide(color: colors.line)),
      ),
      child: ListTile(
        onTap: onTap,
        tileColor: danger ? colors.dangerSoft : null,
        contentPadding: EdgeInsetsDirectional.symmetric(horizontal: spacing.md),
        title: Text(
          '${l10n.invoiceLineNo(ltrIsolate('${line.lineNo}'))} · '
          '${line.rawName}',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product,
              style: textTheme.bodyMedium?.copyWith(
                color: unresolved || hasError ? colors.danger : colors.ink,
              ),
            ),
            Text(
              l10n.invoiceLineQuantityPrice(
                ltrIsolate(DecimalFormatter.formatQuantity(line.quantity)),
                l10n.moneyAmount(
                  ltrIsolate(DecimalFormatter.formatMoney(line.unitPrice)),
                ),
              ),
              style: context.typo.numberSmall.copyWith(color: colors.muted),
            ),
            if (details.isNotEmpty)
              Text(
                details.join(' · '),
                style: textTheme.bodySmall?.copyWith(color: colors.muted),
              ),
            if (hasError)
              Text(
                l10n.errorInvoiceLineProductRequired,
                style: textTheme.bodySmall?.copyWith(color: colors.danger),
              ),
            for (final message in messages)
              Text(
                message,
                style: textTheme.bodySmall?.copyWith(color: colors.danger),
              ),
            SizedBox(height: spacing.xxs),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lineTotal != null) MoneyText(lineTotal),
            if (onRemove != null)
              IconButton(
                tooltip: l10n.invoiceLineRemove,
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, color: colors.danger),
              ),
          ],
        ),
      ),
    );
  }
}
