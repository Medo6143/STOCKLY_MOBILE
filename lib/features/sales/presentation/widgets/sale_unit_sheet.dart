import 'package:flutter/material.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The units of a cart line's product; pops with the chosen unit id.
class SaleUnitSheet extends StatelessWidget {
  const new({required this.line, super.key});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          title: Text(
            l10n.salesChooseUnit,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final unit in line.units)
          ListTile(
            title: Text(unit.name),
            trailing: MoneyText(unit.sellPrice),
            selected: unit.id == line.unit.id,
            onTap: () => Navigator.of(context).pop(unit.id),
          ),
      ],
    );
  }
}
