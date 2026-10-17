import 'package:flutter/material.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The barcode field of the quick sale (design §11): typed by hand or by
/// a Bluetooth/USB keyboard-wedge scanner, which ends each code with
/// Enter. Each submitted code clears the field and keeps the focus for
/// the next one. [onCamera] opens the camera scanner.
class BarcodeEntryField extends StatefulWidget {
  const new({
    required this.onSubmitted,
    required this.enabled,
    this.onCamera,
    super.key,
  });

  final ValueChanged<String> onSubmitted;
  final bool enabled;
  final VoidCallback? onCamera;

  @override
  State<BarcodeEntryField> createState() => _BarcodeEntryFieldState();
}

class _BarcodeEntryFieldState extends State<BarcodeEntryField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    _controller.clear();
    widget.onSubmitted(value);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onCamera = widget.onCamera;
    return TextField(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      autofocus: true,
      textDirection: TextDirection.ltr,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: TextInputAction.done,
      onSubmitted: _submit,
      decoration: InputDecoration(
        labelText: l10n.salesBarcodeLabel,
        prefixIcon: const Icon(Icons.qr_code_rounded),
        suffixIcon: onCamera == null
            ? null
            : IconButton(
                tooltip: l10n.salesScanWithCamera,
                onPressed: widget.enabled ? onCamera : null,
                icon: const Icon(Icons.photo_camera_outlined),
              ),
      ),
    );
  }
}
