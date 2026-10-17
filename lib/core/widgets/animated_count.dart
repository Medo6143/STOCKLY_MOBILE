import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';

/// A whole number that counts up from 0 to [value] when it first shows or
/// when [value] changes (design-refresh brief). It moves in
/// `MotionGeometry.counterSteps` integer steps and always ends on [value]
/// exactly. Under reduce motion it shows [value] at once.
class AnimatedCount extends StatelessWidget {
  const new(this.value, {required this.style, super.key});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    Widget text(int shown) => Text(ltrIsolate('$shown'), style: style);
    if (StocklyMotion.of(context).reduced || value == 0) {
      return text(value);
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0, end: 1),
      duration: context.durations.counter,
      curve: StocklyCurves.counter,
      builder: (context, progress, _) {
        final step = (progress * MotionGeometry.counterSteps).round();
        return text(value * step ~/ MotionGeometry.counterSteps);
      },
    );
  }
}
