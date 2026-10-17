import 'package:flutter/material.dart';
import 'package:stockly/core/widgets/primary_button.dart';

/// The main button of a product form: a full-width pill with press
/// feedback and a spinner while [isBusy].
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
  Widget build(BuildContext context) =>
      PrimaryButton(label: label, busy: isBusy, onPressed: onPressed);
}
