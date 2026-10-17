import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// The cashier's price for one cart line (contract S1 `unitPrice`). Blank
/// charges [listPrice], the unit's sell price, shown as the hint.
class PriceOverrideField extends StatefulWidget {
  const new({
    required this.text,
    required this.listPrice,
    required this.enabled,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final String text;
  final Money listPrice;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  State<PriceOverrideField> createState() => _PriceOverrideFieldState();
}

class _PriceOverrideFieldState extends State<PriceOverrideField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(PriceOverrideField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecimalField(
      controller: _controller,
      label: l10n.salesPriceLabel,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      errorText: widget.errorText,
      helperText: l10n.salesListPrice(
        ltrIsolate(DecimalFormatter.formatMoney(widget.listPrice)),
      ),
    );
  }
}
