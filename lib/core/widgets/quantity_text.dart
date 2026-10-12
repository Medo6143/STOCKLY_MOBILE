import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// A quantity with its unit name, kept LTR inside RTL text. Negative stock
/// is shown in the danger color, low stock in the warning color (design
/// §5.4).
class QuantityText extends StatelessWidget {
  const new(
    this.quantity, {
    this.unit,
    this.isLow = false,
    this.signed = false,
    this.style,
    super.key,
  });

  final Quantity quantity;

  /// The unit name shown after the number, if any.
  final String? unit;

  /// Colors the text as low stock.
  final bool isLow;

  /// Shows `+` before positive values (stock changes).
  final bool signed;

  /// Defaults to `StocklyTypography.numberMedium`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final number = ltrIsolate(
      signed
          ? DecimalFormatter.formatSignedQuantity(quantity)
          : DecimalFormatter.formatQuantity(quantity),
    );
    final unit = this.unit;
    final color = quantity.isNegative
        ? colors.danger
        : isLow
        ? colors.warning
        : colors.ink;
    return Text(
      unit == null
          ? number
          : AppLocalizations.of(context).quantityWithUnit(number, unit),
      style: (style ?? context.typo.numberMedium).copyWith(color: color),
    );
  }
}
