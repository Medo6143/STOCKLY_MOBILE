import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The brand at the top of the auth screens: a mint gradient tile with the
/// app's icon next to the wordmark, then a title and a subtitle.
class AuthHeader extends StatelessWidget {
  const new({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: spacing.huge,
              height: spacing.huge,
              decoration: BoxDecoration(
                borderRadius: context.radii.circular(context.radii.md),
                gradient: LinearGradient(
                  begin: AlignmentDirectional.topStart,
                  end: AlignmentDirectional.bottomEnd,
                  colors: [colors.heroStart, colors.heroEnd],
                ),
                boxShadow: context.elevation.level1,
              ),
              child: Icon(Icons.receipt_long_rounded, color: colors.mint),
            ),
            SizedBox(width: spacing.sm),
            Text(
              AppLocalizations.of(context).appName,
              style: context.typo.wordmark.copyWith(color: colors.ink),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        Text(title, style: textTheme.headlineMedium),
        SizedBox(height: spacing.xxs),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}
