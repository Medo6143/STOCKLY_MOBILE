import 'package:flutter/widgets.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';

/// The tab branches of the home shell with a fade-through between them
/// (design-refresh brief): the old tab fades out, then the new one fades
/// in while it scales up slightly. Like `IndexedStack`, every branch keeps
/// its state; branches that are not shown are offstage with their tickers
/// paused. Under reduce motion the switch is instant (rule 39).
class FadeThroughBranches extends StatelessWidget {
  const new({required this.currentIndex, required this.children, super.key});

  final int currentIndex;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (index, child) in children.indexed)
        _Branch(active: index == currentIndex, child: child),
    ],
  );
}

class _Branch extends StatefulWidget {
  const new({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Branch> createState() => _BranchState();
}

class _BranchState extends State<_Branch> {
  /// `false` once a tab that was left has finished fading out.
  late bool _onstage = widget.active;

  @override
  void didUpdateWidget(_Branch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active) {
      _onstage = true;
    }
  }

  void _faded() {
    if (!widget.active && _onstage && mounted) {
      setState(() => _onstage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = StocklyMotion.of(context);
    if (motion.reduced) {
      _onstage = widget.active;
    }
    final active = widget.active;
    final duration = motion.resolve(context.durations.page);
    final curve = active
        ? StocklyCurves.fadeThroughIn
        : StocklyCurves.fadeThroughOut;
    return Offstage(
      offstage: !_onstage,
      child: TickerMode(
        enabled: _onstage,
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: AnimatedOpacity(
              opacity: active ? 1 : 0,
              duration: duration,
              curve: curve,
              onEnd: motion.reduced ? null : _faded,
              child: AnimatedScale(
                scale: active ? 1 : MotionGeometry.fadeThroughScale,
                duration: duration,
                curve: curve,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
