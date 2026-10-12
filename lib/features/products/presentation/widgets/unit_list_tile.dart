import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One unit of a product: name, how many base units it holds, sell price
/// and barcode. [onTap] is `null` when the unit cannot be edited.
class UnitListTile extends StatelessWidget {
  const new({
    required this.unit,
    required this.baseUnitName,
    required this.onTap,
    super.key,
  });

  final ProductUnit unit;
  final String baseUnitName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = context.typo.numberSmall.copyWith(
      color: context.colors.muted,
    );
    final barcode = unit.barcode;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsetsDirectional.symmetric(
        horizontal: context.spacing.md,
      ),
      title: Text(unit.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            unit.isBase
                ? l10n.productsDetailBaseUnit
                : l10n.productsUnitFactor(
                    unit.name,
                    ltrIsolate(DecimalFormatter.formatFactor(unit.factor)),
                    baseUnitName,
                  ),
          ),
          if (barcode != null) Text(ltrIsolate(barcode), style: muted),
        ],
      ),
      trailing: MoneyText(unit.sellPrice),
    );
  }
}
