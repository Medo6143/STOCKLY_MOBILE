import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/animated_count.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/core/widgets/surface_card.dart';

/// How a dashboard count is colored.
enum SummaryTone { neutral, warning, danger }

/// One dashboard count (design §11): a tinted icon, the number counting up
/// and its label. A count above zero in a [SummaryTone.warning] or
/// [SummaryTone.danger] card is colored; tapping opens the matching list.
class SummaryCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.tone = SummaryTone.neutral,
    super.key,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final SummaryTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final alert = count > 0 && tone != SummaryTone.neutral;
    final accent = !alert
        ? colors.ink
        : switch (tone) {
            SummaryTone.neutral => colors.ink,
            SummaryTone.warning => colors.warning,
            SummaryTone.danger => colors.danger,
          };
    final badge = switch (tone) {
      SummaryTone.neutral => PillTone.mint,
      SummaryTone.warning when alert => PillTone.warning,
      SummaryTone.danger when alert => PillTone.danger,
      _ => PillTone.neutral,
    };
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LeadingBadge(icon: icon, tone: badge),
          SizedBox(height: spacing.sm),
          AnimatedCount(
            count,
            style: context.typo.numberLarge.copyWith(color: accent),
          ),
          SizedBox(height: spacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}
