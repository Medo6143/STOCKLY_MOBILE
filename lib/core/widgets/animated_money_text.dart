import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/core/widgets/money_text.dart';

/// An EGP amount that counts up from 0 to [money] (design-refresh brief).
/// Every frame shows an exact [Money] with 2 decimals: the amount in
/// piastres is split into `MotionGeometry.counterSteps` integer steps, so
/// no `double` ever reaches the text, and the last step is [money] itself.
/// Under reduce motion it shows [money] at once.
class AnimatedMoneyText extends StatelessWidget {
  const new(this.money, {this.style, super.key});

  final Money money;

  /// Defaults to the [MoneyText] style.
  final TextStyle? style;

  static final Decimal _piastresPerPound = Decimal.fromInt(100);

  /// [money] after [step] of `MotionGeometry.counterSteps` steps.
  static Money atStep(Money money, int step) {
    if (step >= MotionGeometry.counterSteps) {
      return money;
    }
    final piastres = (money.value * _piastresPerPound).toBigInt();
    final shown =
        piastres *
        BigInt.from(step) ~/
        BigInt.from(MotionGeometry.counterSteps);
    return Money.fromDecimal(
      (Decimal.fromBigInt(shown) / _piastresPerPound).toDecimal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (StocklyMotion.of(context).reduced || money == Money.zero) {
      return MoneyText(money, style: style);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(money),
      tween: Tween(begin: 0, end: 1),
      duration: context.durations.counter,
      curve: StocklyCurves.counter,
      builder: (context, progress, _) => MoneyText(
        atStep(money, (progress * MotionGeometry.counterSteps).round()),
        style: style,
      ),
    );
  }
}
