import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';

/// How a dashboard count is colored.
enum SummaryTone { neutral, warning, danger }

/// One dashboard count (design §11): an icon, the number and its label.
/// A count above zero in a [SummaryTone.warning] or [SummaryTone.danger]
/// card is colored; tapping opens the matching list.
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
    final accent = count == 0
        ? colors.ink
        : switch (tone) {
            SummaryTone.neutral => colors.ink,
            SummaryTone.warning => colors.warning,
            SummaryTone.danger => colors.danger,
          };
    return Card(
      margin: EdgeInsetsDirectional.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsetsDirectional.all(spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent),
              SizedBox(height: spacing.xs),
              Text(
                ltrIsolate('$count'),
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
        ),
      ),
    );
  }
}
