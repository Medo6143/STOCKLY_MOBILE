import 'package:flutter/widgets.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';

/// Shrinks [child] slightly while a finger is down on it (design-refresh
/// brief: pressed scale on buttons). It only listens to pointers, so taps
/// still reach the child. Under reduce motion nothing scales (rule 39).
class PressScale extends StatefulWidget {
  const new({required this.child, this.enabled = true, super.key});

  final Widget child;

  /// `false` for a disabled button: no feedback.
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed && mounted) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = StocklyMotion.of(context).reduced;
    final pressed = _pressed && widget.enabled && !reduced;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: pressed ? MotionGeometry.pressedScale : 1,
        duration: StocklyMotion.of(context).resolve(context.durations.fast),
        curve: StocklyCurves.press,
        child: widget.child,
      ),
    );
  }
}
