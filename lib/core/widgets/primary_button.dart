import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/press_scale.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The main action of a form or screen (design-refresh brief): a
/// full-width pill `FilledButton` that shrinks slightly when pressed, with
/// a spinner instead of its label while [busy].
class PrimaryButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final onPressed = busy ? null : this.onPressed;
    return PressScale(
      enabled: onPressed != null,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onPressed,
          child: busy
              ? SizedBox.square(
                  dimension: spacing.lg,
                  child: CircularProgressIndicator(
                    strokeWidth: spacing.xxs / 2,
                    semanticsLabel: AppLocalizations.of(context).commonLoading,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}
