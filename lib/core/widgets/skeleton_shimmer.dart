import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_motion.dart';

/// Runs a subtle shimmer over a loading skeleton (design-refresh brief),
/// drawn by flutter_animate's [ShimmerEffect] on a repeating controller.
/// The controller is owned here rather than by an `Animate` widget, whose
/// start-up timer would outlive a screen that leaves its loading state at
/// once. Under reduce motion the skeleton stays still and nothing ticks
/// (rule 39).
class SkeletonShimmer extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  /// [EffectEntry] needs an owner; this one is never mounted.
  static final Animate _owner = Animate();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (StocklyMotion.of(context).reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller
        ..duration = context.durations.shimmer
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (StocklyMotion.of(context).reduced) {
      return widget.child;
    }
    final duration = context.durations.shimmer;
    final effect = ShimmerEffect(
      duration: duration,
      color: context.colors.shimmerHighlight,
      padding: 0,
    );
    return effect.build(
      context,
      widget.child,
      _controller,
      EffectEntry(
        effect: effect,
        delay: Duration.zero,
        duration: duration,
        curve: Curves.linear,
        owner: _owner,
      ),
    );
  }
}
