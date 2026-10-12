import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/presentation/widgets/products_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One stock movement (design §11): reason, signed change, balance after,
/// note, time, and a link to its invoice or sale.
class MovementListTile extends StatelessWidget {
  const new({
    required this.movement,
    required this.onOpenInvoice,
    required this.onOpenSale,
    this.baseUnitName,
    super.key,
  });

  final StockMovement movement;

  /// The product's base unit, when known.
  final String? baseUnitName;
  final ValueChanged<String> onOpenInvoice;
  final ValueChanged<String> onOpenSale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final note = movement.note;
    final invoiceId = movement.invoiceId;
    final saleId = movement.saleId;
    final balance = ltrIsolate(
      DecimalFormatter.formatQuantity(movement.balanceAfter),
    );
    final unit = baseUnitName;
    return ListTile(
      contentPadding: EdgeInsetsDirectional.symmetric(
        horizontal: context.spacing.md,
      ),
      title: Text(movementReasonLabel(l10n, movement.reason)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.movementsBalanceAfter(
              unit == null ? balance : l10n.quantityWithUnit(balance, unit),
            ),
          ),
          if (note != null) Text(note, style: textTheme.bodySmall),
          Text(
            ltrIsolate(
              DateFormatter.dateTime(
                movement.createdAt,
                Localizations.localeOf(context).languageCode,
              ),
            ),
            style: textTheme.bodySmall?.copyWith(color: colors.muted),
          ),
          if (invoiceId != null)
            TextButton(
              onPressed: () => onOpenInvoice(invoiceId),
              child: Text(l10n.movementsOpenInvoice),
            ),
          if (saleId != null)
            TextButton(
              onPressed: () => onOpenSale(saleId),
              child: Text(l10n.movementsOpenSale),
            ),
        ],
      ),
      trailing: QuantityText(movement.quantityChange, signed: true),
    );
  }
}
