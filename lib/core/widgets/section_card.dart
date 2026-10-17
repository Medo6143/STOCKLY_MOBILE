import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/surface_card.dart';

/// A titled group of form fields or facts on a card (design-refresh
/// brief). [children] are spaced by `spacing.md`.
class SectionCard extends StatelessWidget {
  const new({
    required this.children,
    this.title,
    this.icon,
    this.trailing,
    super.key,
  });

  final String? title;
  final IconData? icon;

  /// Shown at the end of the title row, for example an "Add" button.
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final title = this.title;
    final icon = this.icon;
    final trailing = this.trailing;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colors.mint),
                  SizedBox(width: spacing.xs),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            SizedBox(height: spacing.md),
          ],
          for (final (index, child) in children.indexed) ...[
            if (index > 0) SizedBox(height: spacing.md),
            child,
          ],
        ],
      ),
    );
  }
}
