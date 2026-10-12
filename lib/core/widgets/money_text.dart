import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// An EGP amount in the brand's number style, kept LTR inside RTL text
/// (design §5.4).
class MoneyText extends StatelessWidget {
  const new(this.money, {this.style, super.key});

  final Money money;

  /// Defaults to `StocklyTypography.numberMedium` in the ink color.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    AppLocalizations.of(context)
        .moneyAmount(ltrIsolate(DecimalFormatter.formatMoney(money))),
    style:
        style ?? context.typo.numberMedium.copyWith(color: context.colors.ink),
  );
}
