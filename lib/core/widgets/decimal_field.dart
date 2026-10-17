import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A text field for money, quantities and factors (design §5.3): Western
/// and Arabic-Indic digits, `.`/`٫` separators and, when [signed], a
/// minus. Never rounds; the notifier parses the text exactly.
class DecimalField extends StatelessWidget {
  const new({
    required this.controller,
    required this.label,
    required this.enabled,
    this.signed = false,
    this.errorText,
    this.helperText,
    this.readOnly = false,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final bool signed;
  final String? errorText;
  final String? helperText;
  final bool readOnly;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;

  static final RegExp _unsigned = RegExp('[0-9٠-٩۰-۹.٫,٬]');
  static final RegExp _signed = RegExp('[0-9٠-٩۰-۹.٫,٬-]');

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    enabled: enabled,
    readOnly: readOnly,
    keyboardType: TextInputType.numberWithOptions(
      decimal: true,
      signed: signed,
    ),
    inputFormatters: [
      FilteringTextInputFormatter.allow(signed ? _signed : _unsigned),
    ],
    textDirection: TextDirection.ltr,
    textInputAction: textInputAction,
    decoration: InputDecoration(
      labelText: label,
      errorText: errorText,
      helperText: helperText,
      errorMaxLines: 3,
      helperMaxLines: 2,
    ),
  );
}
