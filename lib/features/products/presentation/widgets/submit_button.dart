import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The main button of a product form, with a spinner while [isBusy].
class SubmitButton extends StatelessWidget {
  const new({
    required this.label,
    required this.isBusy,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool isBusy;

  /// `null` disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return FilledButton(
      onPressed: isBusy ? null : onPressed,
      child: isBusy
          ? SizedBox.square(
              dimension: spacing.lg,
              child: CircularProgressIndicator(
                strokeWidth: spacing.xxs / 2,
                semanticsLabel: AppLocalizations.of(context).commonLoading,
              ),
            )
          : Text(label),
    );
  }
}
