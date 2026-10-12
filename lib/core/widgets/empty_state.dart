import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The call to action of an [EmptyState].
@immutable
final class EmptyStateAction {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Shown when a list or screen has no data (rule 34).
class EmptyState extends StatelessWidget {
  const new({this.title, this.body, this.action, super.key});

  /// The generic empty state ("Nothing here yet").
  const new generic({super.key}) : title = null, body = null, action = null;

  /// Defaults to `commonEmptyTitle`.
  final String? title;

  /// Defaults to `commonEmptyBody`.
  final String? body;
  final EmptyStateAction? action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: spacing.huge,
              color: context.colors.muted,
            ),
            SizedBox(height: spacing.md),
            Text(
              title ?? l10n.commonEmptyTitle,
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.xs),
            Text(
              body ?? l10n.commonEmptyBody,
              style: textTheme.bodyMedium?.copyWith(
                color: context.colors.muted,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              SizedBox(height: spacing.xl),
              FilledButton(
                onPressed: action.onPressed,
                child: Text(action.label),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
