import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/auth/presentation/widgets/auth_labels.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Pharmacy, grocery, mobile shop or other (contract `shopType`).
class ShopTypePicker extends StatelessWidget {
  const new({
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.errorText,
    super.key,
  });

  final ShopType? selected;
  final bool enabled;
  final ValueChanged<ShopType> onSelected;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final errorText = this.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.authShopTypeLabel, style: textTheme.labelLarge),
        SizedBox(height: spacing.xs),
        Wrap(
          spacing: spacing.xs,
          runSpacing: spacing.xs,
          children: [
            for (final type in ShopType.values)
              ChoiceChip(
                label: Text(shopTypeLabel(l10n, type)),
                selected: selected == type,
                onSelected: enabled ? (_) => onSelected(type) : null,
              ),
          ],
        ),
        if (errorText != null) ...[
          SizedBox(height: spacing.xxs),
          Text(
            errorText,
            style: textTheme.bodySmall?.copyWith(color: context.colors.danger),
          ),
        ],
      ],
    );
  }
}
