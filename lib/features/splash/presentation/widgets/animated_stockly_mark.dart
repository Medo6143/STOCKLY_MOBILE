import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/splash_layout.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/theme/stockly_motion.dart';
import 'package:stockly/features/splash/presentation/widgets/stockly_mark_painter.dart';

/// The splash mark animation (design §10.3): one controller of
/// `SplashTimings.controller`, every element on its own interval. Under
/// "reduce motion" the controller sits at its final frame and never runs
/// (rule 39).
class AnimatedStocklyMark extends StatefulWidget {
  const new({required this.semanticLabel, super.key});

  final String semanticLabel;

  @override
  State<AnimatedStocklyMark> createState() => _AnimatedStocklyMarkState();
}

class _AnimatedStocklyMarkState extends State<AnimatedStocklyMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SplashTimings.controller,
  );
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) {
      return;
    }
    _decided = true;
    if (StocklyMotion.of(context).reduced) {
      _controller.value = _controller.upperBound;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: ExcludeSemantics(
        // A picture, not text: never mirrored (design §8.5).
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.square(
            dimension: SplashLayout.markSize,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: StocklyMarkPainter(
                  progress: _controller.value,
                  paper: colors.markPaper,
                  ink: colors.markInk,
                  mint: colors.markMint,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
