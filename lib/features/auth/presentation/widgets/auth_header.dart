import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The wordmark, a title and a subtitle at the top of the auth screens.
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
        Text(
          AppLocalizations.of(context).appName,
          style: context.typo.wordmark.copyWith(color: colors.ink),
        ),
        SizedBox(height: spacing.lg),
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
