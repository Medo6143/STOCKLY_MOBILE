import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';

/// A small pill: "Low stock" in the warning colors, or any other [label]
/// with its own colors (for example "Archived").
class LowStockBadge extends StatelessWidget {
  const new({required this.label, this.muted = false, super.key});

  final String label;

  /// Neutral colors instead of the warning colors.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: muted ? colors.line : colors.warningSoft,
        borderRadius: context.radii.circular(context.radii.pill),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xxs / 2,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: muted ? colors.muted : colors.warning),
        ),
      ),
    );
  }
}
