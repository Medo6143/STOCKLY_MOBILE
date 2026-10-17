import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';

/// The colours of a [StatusPill].
enum PillTone { neutral, mint, warning, danger }

/// A small status chip with a soft fill (`mintSoft`, `warningSoft`,
/// `dangerSoft`). Its colours animate when the tone changes.
class StatusPill extends StatelessWidget {
  const new({
    required this.label,
    this.tone = PillTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final (background, foreground) = switch (tone) {
      PillTone.neutral => (colors.line, colors.muted),
      PillTone.mint => (colors.mintSoft, colors.ink),
      PillTone.warning => (colors.warningSoft, colors.warning),
      PillTone.danger => (colors.dangerSoft, colors.danger),
    };
    final style = Theme.of(context).textTheme.labelSmall;
    final icon = this.icon;
    final duration = StocklyMotion.of(context)
        .resolve(context.durations.medium);
    return AnimatedContainer(
      duration: duration,
      curve: StocklyCurves.color,
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: spacing.xs,
        vertical: spacing.xxs / 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.radii.circular(context.radii.pill),
      ),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: foreground),
        duration: duration,
        curve: StocklyCurves.color,
        builder: (context, color, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: style?.fontSize, color: color),
              SizedBox(width: spacing.xxs),
            ],
            Text(label, style: style?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
