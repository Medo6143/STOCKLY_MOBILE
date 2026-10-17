import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/features/sales/presentation/widgets/price_override_field.dart';
import 'package:stockly/features/sales/presentation/widgets/sales_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One cart line (design §11): product, unit, quantity, price (the unit's
/// sell price unless overridden), the line total preview and the stock on
/// hand. A line the server or the device rejected is outlined in red.
class CartLineTile extends StatefulWidget {
  const new({
    required this.line,
    required this.enabled,
    required this.onQuantity,
    required this.onPrice,
    required this.onUnit,
    required this.onRemove,
    this.hasError = false,
    this.messages = const [],
    super.key,
  });

  final CartLine line;
  final bool enabled;
  final ValueChanged<String> onQuantity;
  final ValueChanged<String> onPrice;
  final VoidCallback onUnit;
  final VoidCallback onRemove;
  final bool hasError;

  /// Server field messages of this line.
  final List<String> messages;

  @override
  State<CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends State<CartLineTile> {
  late final TextEditingController _quantity = TextEditingController(
    text: widget.line.quantityText,
  );

  @override
  void didUpdateWidget(CartLineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.line.quantityText != _quantity.text) {
      _quantity.text = widget.line.quantityText;
    }
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final spacing = context.spacing;
    final line = widget.line;
    final quantityIssue = line.quantityIssue;
    final priceIssue = line.priceIssue;
    final total = line.totalPreview;
    return Card(
      margin: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xxs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.circular(context.radii.md),
        side: widget.hasError
            ? BorderSide(color: colors.danger)
            : BorderSide.none,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.productName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.salesRemoveLine,
                  onPressed: widget.enabled ? widget.onRemove : null,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Wrap(
              spacing: spacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.salesInStock,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                QuantityText(
                  line.stock,
                  unit: line.baseUnitName,
                  style: context.typo.numberSmall,
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DecimalField(
                    controller: _quantity,
                    label: l10n.salesQuantityLabel,
                    enabled: widget.enabled,
                    onChanged: widget.onQuantity,
                    errorText: quantityIssue == null
                        ? null
                        : saleFieldIssueLabel(l10n, quantityIssue),
                  ),
                ),
                SizedBox(width: spacing.xs),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.enabled ? widget.onUnit : null,
                    icon: const Icon(Icons.straighten_rounded),
                    label: Text(
                      line.unit.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.xs),
            PriceOverrideField(
              text: line.priceText,
              listPrice: line.unit.sellPrice,
              enabled: widget.enabled,
              onChanged: widget.onPrice,
              errorText: priceIssue == null
                  ? null
                  : saleFieldIssueLabel(l10n, priceIssue),
            ),
            for (final message in widget.messages)
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.danger),
              ),
            if (total != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MoneyText(total),
              ),
          ],
        ),
      ),
    );
  }
}
