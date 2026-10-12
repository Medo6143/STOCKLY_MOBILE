import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The low-stock and archived filters of the product list.
class ProductFilterChips extends StatelessWidget {
  const new({required this.query, required this.onChanged, super.key});

  final ProductQuery query;
  final ValueChanged<ProductQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: context.spacing.xs,
      children: [
        FilterChip(
          label: Text(l10n.productsFilterLowStock),
          selected: query.lowStock,
          onSelected: (value) => onChanged(query.copyWith(lowStock: value)),
        ),
        FilterChip(
          label: Text(l10n.productsFilterArchived),
          selected: query.includeArchived,
          onSelected: (value) =>
              onChanged(query.copyWith(includeArchived: value)),
        ),
      ],
    );
  }
}
