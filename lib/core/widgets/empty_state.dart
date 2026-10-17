import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/press_scale.dart';
import 'package:stockly/core/widgets/state_illustration.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The call to action of an [EmptyState].
@immutable
final class EmptyStateAction {
  const new({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// Shown when a list or screen has no data (rule 34): an illustration-style
/// icon in a soft circle, title, body and actions, entering with a fade
/// (design-refresh brief).
class EmptyState extends StatelessWidget {
  const new({
    this.title,
    this.body,
    this.action,
    this.secondaryAction,
    this.icon = Icons.inventory_2_outlined,
    super.key,
  });

  /// The generic empty state ("Nothing here yet").
  const new generic({super.key})
    : title = null,
      body = null,
      action = null,
      secondaryAction = null,
      icon = Icons.inventory_2_outlined;

  /// Defaults to `commonEmptyTitle`.
  final String? title;

  /// Defaults to `commonEmptyBody`.
  final String? body;
  final EmptyStateAction? action;

  /// A second, less prominent call to action under [action].
  final EmptyStateAction? secondaryAction;

  /// The illustration's icon.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    final textTheme = Theme.of(context).textTheme;
    final action = this.action;
    final secondaryAction = this.secondaryAction;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.all(spacing.xl),
        child: Entrance(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StateIllustration(
                icon: icon,
                color: context.colors.mint,
                background: context.colors.mintSoft,
              ),
              SizedBox(height: spacing.lg),
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
                PressScale(
                  child: FilledButton(
                    onPressed: action.onPressed,
                    child: Text(action.label),
                  ),
                ),
              ],
              if (secondaryAction != null) ...[
                SizedBox(height: spacing.xs),
                OutlinedButton(
                  onPressed: secondaryAction.onPressed,
                  child: Text(secondaryAction.label),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
