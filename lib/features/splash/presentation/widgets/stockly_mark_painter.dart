import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/theme/stockly_mark_geometry.dart';

/// Paints the splash mark at [progress] of `SplashTimings.controller`
/// (0 = nothing drawn, 1 = the final frame): paper `pop`, lines `lnIn` then
/// `shrink`, scan beam, data pixels (design §10.2). Every element's timing
/// comes from `SplashTimings`, so the brand timeline lives in one place.
final class StocklyMarkPainter extends CustomPainter {
  new({
    required this.progress,
    required this.paper,
    required this.ink,
    required this.mint,
  });

  final double progress;
  final Color paper;
  final Color ink;
  final Color mint;

  static const Duration _total = SplashTimings.controller;

  /// [step]'s own progress (0 before it starts, 1 after it ends), eased.
  double _eased(SplashStep step, Curve curve) => curve.transform(_raw(step));

  double _raw(SplashStep step) {
    final elapsed = _total * progress;
    final t =
        (elapsed - step.start).inMicroseconds / step.duration.inMicroseconds;
    return t.clamp(0, 1).toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(
        size.width / StocklyMarkGeometry.viewBox,
        size.height / StocklyMarkGeometry.viewBox,
      );
    _paintPaper(canvas);
    _paintLines(canvas);
    _paintBeam(canvas);
    _paintPixels(canvas);
    canvas.restore();
  }

  void _paintPaper(Canvas canvas) {
    final pop = _eased(SplashTimings.paper, SplashCurves.paperPop);
    final opacity = pop.clamp(0, 1).toDouble();
    if (opacity == 0) {
      return;
    }
    const center = StocklyMarkGeometry.paperCenter;
    final scale =
        StocklyMarkGeometry.paperStartScale +
        (1 - StocklyMarkGeometry.paperStartScale) * pop;
    canvas
      ..save()
      ..translate(0, StocklyMarkGeometry.paperRise * (1 - pop))
      ..translate(center.dx, center.dy)
      ..scale(scale)
      ..translate(-center.dx, -center.dy);
    final path = paperPath();
    canvas
      ..drawPath(path, Paint()..color = paper.withValues(alpha: opacity))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = StocklyMarkGeometry.paperStrokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = ink.withValues(alpha: opacity),
      )
      ..restore();
  }

  void _paintLines(Canvas canvas) {
    final paint = Paint()..color = ink;
    for (var i = 0; i < StocklyMarkGeometry.lines.length; i++) {
      final shrinkStep = SplashTimings.linesShrink[i];
      final double scale;
      if (_raw(shrinkStep) > 0) {
        final shrink = _eased(shrinkStep, SplashCurves.lineShrink);
        scale = 1 + (StocklyMarkGeometry.lineShrunkScale - 1) * shrink;
      } else {
        scale = _eased(SplashTimings.linesIn[i], SplashCurves.lineIn);
      }
      if (scale <= 0) {
        continue;
      }
      final line = StocklyMarkGeometry.lines[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(line.left, line.top, line.width * scale, line.height),
          const Radius.circular(StocklyMarkGeometry.lineRadius),
        ),
        paint,
      );
    }
  }

  void _paintBeam(Canvas canvas) {
    final t = _raw(SplashTimings.scanBeam);
    final opacity = _beamOpacity(t);
    if (opacity <= 0) {
      return;
    }
    final dy =
        StocklyMarkGeometry.beamTravel * SplashCurves.scanBeam.transform(t);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        StocklyMarkGeometry.beam.shift(Offset(0, dy)),
        const Radius.circular(StocklyMarkGeometry.beamRadius),
      ),
      Paint()..color = mint.withValues(alpha: opacity),
    );
  }

  /// `scan` keyframes: 0 → 1 by 12 %, 1 until 88 %, → 0 at 100 %, each
  /// segment eased like the CSS timing function.
  static double _beamOpacity(double t) {
    const fadeIn = StocklyMarkGeometry.beamFadeIn;
    const fadeOut = StocklyMarkGeometry.beamFadeOut;
    if (t <= 0 || t >= 1) {
      return 0;
    }
    if (t < fadeIn) {
      return SplashCurves.scanBeam.transform(t / fadeIn);
    }
    if (t <= fadeOut) {
      return 1;
    }
    return 1 - SplashCurves.scanBeam.transform((t - fadeOut) / (1 - fadeOut));
  }

  void _paintPixels(Canvas canvas) {
    for (var i = 0; i < StocklyMarkGeometry.pixels.length; i++) {
      final step = SplashTimings.pixels[i];
      if (_raw(step) <= 0) {
        continue;
      }
      final value = _eased(step, SplashCurves.pixel);
      final target = StocklyMarkGeometry.pixelOpacities[i];
      final opacity = (target * value).clamp(0, 1).toDouble();
      final scale = math.max(
        0,
        StocklyMarkGeometry.pixelStartScale +
            (1 - StocklyMarkGeometry.pixelStartScale) * value,
      );
      final pixel = StocklyMarkGeometry.pixels[i];
      final center = pixel.center;
      canvas
        ..save()
        ..translate(-StocklyMarkGeometry.pixelSlide * (1 - value), 0)
        ..translate(center.dx, center.dy)
        ..scale(scale.toDouble())
        ..translate(-center.dx, -center.dy)
        ..drawRRect(
          RRect.fromRectAndRadius(
            pixel,
            const Radius.circular(StocklyMarkGeometry.pixelRadius),
          ),
          Paint()..color = mint.withValues(alpha: opacity),
        )
        ..restore();
    }
  }

  /// The receipt outline of `stockly-mark.svg`.
  static Path paperPath() {
    const radius = Radius.circular(StocklyMarkGeometry.paperCornerRadius);
    final path = Path()
      ..moveTo(
        StocklyMarkGeometry.paperTopStart.dx,
        StocklyMarkGeometry.paperTopStart.dy,
      )
      ..lineTo(
        StocklyMarkGeometry.paperTopEnd.dx,
        StocklyMarkGeometry.paperTopEnd.dy,
      )
      ..arcToPoint(StocklyMarkGeometry.paperRightTop, radius: radius);
    for (final point in StocklyMarkGeometry.paperTornEdge) {
      path.lineTo(point.dx, point.dy);
    }
    return path
      ..lineTo(
        StocklyMarkGeometry.paperLeftTop.dx,
        StocklyMarkGeometry.paperLeftTop.dy,
      )
      ..arcToPoint(StocklyMarkGeometry.paperTopStart, radius: radius)
      ..close();
  }

  @override
  bool shouldRepaint(StocklyMarkPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.paper != paper ||
      oldDelegate.ink != ink ||
      oldDelegate.mint != mint;
}
