import 'package:flutter/material.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Chooses the unit of an adjustment or count. `null` is the base unit,
/// which the contract uses when no unit id is sent.
class UnitPicker extends StatelessWidget {
  const new({
    required this.units,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  /// Base unit first (contract `ProductDetail.units`).
  final List<ProductUnit> units;

  /// The chosen unit id; `null` is the base unit.
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String?>(
    initialValue: value,
    decoration: InputDecoration(
      labelText: AppLocalizations.of(context).stockUnit,
      errorText: errorText,
    ),
    items: [
      for (final unit in units)
        DropdownMenuItem(
          value: unit.isBase ? null : unit.id,
          child: Text(unit.name),
        ),
    ],
    onChanged: enabled ? onChanged : null,
  );
}
