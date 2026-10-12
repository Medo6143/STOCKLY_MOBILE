import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/splash_layout.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/theme/stockly_motion.dart';

/// Three mint dots shown while the session check runs. They rest at 25 %
/// and pulse from 2.3 s, 2.45 s and 2.6 s in a 1.2 s cycle (brand `dot`).
/// The time comes from one ticker started with the splash, so the brand
/// delays hold exactly; under "reduce motion" they stay at rest (rule 39).
class SplashLoadingDots extends StatefulWidget {
  const new({super.key});

  @override
  State<SplashLoadingDots> createState() => _SplashLoadingDotsState();
}

class _SplashLoadingDotsState extends State<SplashLoadingDots>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(
    (elapsed) => setState(() => _elapsed = elapsed),
  );
  Duration _elapsed = Duration.zero;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_decided) {
      _decided = true;
      if (!StocklyMotion.of(context).reduced) {
        _ticker.start();
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// `@keyframes dot`: rest → peak at 50 % → rest, each half eased.
  static double opacityAt(Duration elapsed, Duration delay) {
    if (elapsed < delay) {
      return SplashLayout.dotRestOpacity;
    }
    final cycle = SplashTimings.dotCycle.inMicroseconds;
    final phase = ((elapsed - delay).inMicroseconds % cycle) / cycle;
    final half = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return SplashLayout.dotRestOpacity +
        (SplashLayout.dotPeakOpacity - SplashLayout.dotRestOpacity) *
            SplashCurves.dot.transform(half);
  }

  @override
  Widget build(BuildContext context) {
    final mint = context.colors.markMint;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, delay) in SplashTimings.dotDelays.indexed) ...[
            if (index > 0) const SizedBox(width: SplashLayout.dotGap),
            Opacity(
              opacity: opacityAt(_elapsed, delay),
              child: DecoratedBox(
                decoration: BoxDecoration(color: mint, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: SplashLayout.dotSize),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
