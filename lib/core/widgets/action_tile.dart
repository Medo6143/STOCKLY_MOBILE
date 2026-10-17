import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';

/// A tappable action card: a tinted icon, a title, an optional subtitle
/// and a chevron that points to the end edge (it flips in RTL).
class ActionTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tone = PillTone.mint,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// `null` disables the tile.
  final VoidCallback? onTap;
  final PillTone tone;

  /// Replaces the chevron, for example with a spinner.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
    return SurfaceCard(
      onTap: onTap,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      child: Row(
        children: [
          LeadingBadge(icon: icon, tone: tone),
          SizedBox(width: spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    color: tone == PillTone.danger ? colors.danger : null,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: textTheme.bodySmall?.copyWith(color: colors.muted),
                  ),
              ],
            ),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: colors.muted),
        ],
      ),
    );
  }
}
