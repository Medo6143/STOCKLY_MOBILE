import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';

/// Fades [child] in while it rises `MotionGeometry.entranceRise` pixels,
/// after `stagger × index` (design-refresh brief). Whether it plays is
/// decided once, when it is first built: inside an [EntranceScope] only on
/// the scope's first frame. Under reduce motion it shows the final frame
/// and never ticks (rule 39).
class Entrance extends StatefulWidget {
  const new({required this.child, this.index = 0, super.key});

  final Widget child;

  /// Position in a staggered group; 0 starts at once.
  final int index;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> {
  late final bool _plays = EntranceScope.isOpen(context);

  @override
  Widget build(BuildContext context) {
    if (!_plays || StocklyMotion.of(context).reduced) {
      return widget.child;
    }
    final durations = context.durations;
    final delay =
        durations.stagger *
        math.min(widget.index, MotionGeometry.maxStaggeredItems);
    final total = delay + durations.entrance;
    final start = delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: StocklyCurves.entrance),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, MotionGeometry.entranceRise * (1 - t)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
