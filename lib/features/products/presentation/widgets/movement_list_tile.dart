import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';
import 'package:stockly/features/products/presentation/widgets/products_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One stock movement (design §11) as a card: a badge for the reason,
/// tinted by the direction of the change, reason, signed change, balance
/// after, note, time, and a link to its invoice or sale.
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

  static IconData _iconOf(StockMovementReason reason) => switch (reason) {
    StockMovementReason.invoiceReceipt => Icons.receipt_long_rounded,
    StockMovementReason.sale => Icons.shopping_bag_outlined,
    StockMovementReason.manualAdjustment => Icons.tune_rounded,
    StockMovementReason.stockCount => Icons.fact_check_outlined,
    StockMovementReason.invoiceReversal => Icons.undo_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final note = movement.note;
    final invoiceId = movement.invoiceId;
    final saleId = movement.saleId;
    final balance = ltrIsolate(
      DecimalFormatter.formatQuantity(movement.balanceAfter),
    );
    final unit = baseUnitName;
    final small = textTheme.bodySmall?.copyWith(color: colors.muted);
    return SurfaceCard(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadingBadge(
            icon: _iconOf(movement.reason),
            tone: movement.quantityChange.isNegative
                ? PillTone.danger
                : PillTone.mint,
          ),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movementReasonLabel(l10n, movement.reason),
                  style: textTheme.titleMedium,
                ),
                Text(
                  l10n.movementsBalanceAfter(
                    unit == null
                        ? balance
                        : l10n.quantityWithUnit(balance, unit),
                  ),
                  style: textTheme.bodyMedium,
                ),
                if (note != null) Text(note, style: textTheme.bodySmall),
                Text(
                  ltrIsolate(
                    DateFormatter.dateTime(
                      movement.createdAt,
                      Localizations.localeOf(context).languageCode,
                    ),
                  ),
                  style: small,
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
          ),
          SizedBox(width: spacing.sm),
          QuantityText(movement.quantityChange, signed: true),
        ],
      ),
    );
  }
}
