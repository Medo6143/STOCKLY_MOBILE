import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_motion.dart';

/// Success feedback (design-refresh brief): a mint circle pops in and a
/// tick draws itself inside it. Under reduce motion it shows the finished
/// check and never ticks (rule 39).
class SuccessCheck extends StatelessWidget {
  const new({this.size, this.semanticLabel, super.key});

  /// Defaults to `spacing.xl`.
  final double? size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dimension = size ?? context.spacing.xl;
    Widget frame(double progress) => CustomPaint(
      size: Size.square(dimension),
      painter: _CheckPainter(
        progress: progress,
        circle: colors.mint,
        tick: colors.onMint,
      ),
    );
    final check = StocklyMotion.of(context).reduced
        ? frame(1)
        : TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: context.durations.success,
            builder: (context, progress, _) => frame(progress),
          );
    return Semantics(label: semanticLabel, image: true, child: check);
  }
}

class _CheckPainter extends CustomPainter {
  const new({required this.progress, required this.circle, required this.tick});

  final double progress;
  final Color circle;
  final Color tick;

  static const Offset _start = Offset(0.28, 0.52);
  static const Offset _corner = Offset(0.44, 0.67);
  static const Offset _end = Offset(0.73, 0.36);
  static const double _strokeShare = 0.1;

  @override
  void paint(Canvas canvas, Size size) {
    final pop = StocklyCurves.successPop.transform(progress);
    final scale = lerpDouble(MotionGeometry.successStartScale, 1, pop)!;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      size.shortestSide / 2 * scale,
      Paint()..color = circle.withValues(alpha: progress),
    );
    final drawn = StocklyCurves.successTick.transform(progress);
    if (drawn <= 0) {
      return;
    }
    Offset at(Offset share) =>
        Offset(share.dx * size.width, share.dy * size.height);
    final path = Path()
      ..moveTo(at(_start).dx, at(_start).dy)
      ..lineTo(at(_corner).dx, at(_corner).dy)
      ..lineTo(at(_end).dx, at(_end).dy);
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * drawn;
    final visible = Path();
    for (final metric in metrics) {
      final length = remaining.clamp(0, metric.length).toDouble();
      visible.addPath(metric.extractPath(0, length), Offset.zero);
      remaining -= length;
    }
    canvas.drawPath(
      visible,
      Paint()
        ..color = tick
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = size.shortestSide * _strokeShare,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.circle != circle ||
      oldDelegate.tick != tick;
}
