import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// One unit of a product, a row inside the units card: name, how many
/// base units it holds, sell price and barcode. [onTap] is `null` when the
/// unit cannot be edited.
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
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final muted = context.typo.numberSmall.copyWith(color: colors.muted);
    final barcode = unit.barcode;
    return InkWell(
      onTap: onTap,
      customBorder: RoundedRectangleBorder(
        borderRadius: context.radii.circular(context.radii.md),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(vertical: spacing.xs),
        child: Row(
          children: [
            LeadingBadge(
              icon: unit.isBase
                  ? Icons.looks_one_outlined
                  : Icons.layers_outlined,
              tone: unit.isBase ? PillTone.mint : PillTone.neutral,
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(unit.name, style: textTheme.titleMedium),
                  Text(
                    unit.isBase
                        ? l10n.productsDetailBaseUnit
                        : l10n.productsUnitFactor(
                            unit.name,
                            ltrIsolate(
                              DecimalFormatter.formatFactor(unit.factor),
                            ),
                            baseUnitName,
                          ),
                    style: textTheme.bodySmall?.copyWith(color: colors.muted),
                  ),
                  if (barcode != null) Text(ltrIsolate(barcode), style: muted),
                ],
              ),
            ),
            SizedBox(width: spacing.sm),
            MoneyText(unit.sellPrice),
          ],
        ),
      ),
    );
  }
}
