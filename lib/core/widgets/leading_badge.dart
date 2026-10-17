import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/status_pill.dart';

/// The tinted square at the start of a list card: an icon, or the
/// initials of a name (design-refresh brief).
class LeadingBadge extends StatelessWidget {
  const new({
    this.icon,
    this.text,
    this.tone = PillTone.mint,
    this.size,
    super.key,
  }) : assert(icon != null || text != null, 'an icon or a text');

  final IconData? icon;

  /// Initials, shown instead of [icon] when not empty.
  final String? text;
  final PillTone tone;

  /// Defaults to `spacing.xxxl`.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimension = size ?? context.spacing.xxxl;
    final (background, foreground) = switch (tone) {
      PillTone.neutral => (colors.line, colors.muted),
      PillTone.mint => (colors.mintSoft, colors.ink),
      PillTone.warning => (colors.warningSoft, colors.warning),
      PillTone.danger => (colors.dangerSoft, colors.danger),
    };
    final text = this.text;
    return SizedBox.square(
      dimension: dimension,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: context.radii.circular(context.radii.md),
        ),
        child: Center(
          child: text != null && text.isNotEmpty
              ? Text(
                  text,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: foreground),
                )
              : Icon(icon, color: foreground),
        ),
      ),
    );
  }
}
