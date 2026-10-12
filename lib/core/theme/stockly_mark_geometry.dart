import 'dart:ui';

/// The Stockly mark in the 64×64 viewBox of `brand/stockly-mark.svg`, with
/// the animated splash parts of `brand/stockly-brand.html` (design §10).
abstract final class StocklyMarkGeometry {
  static const double viewBox = 64;

  /// Receipt outline: `M16 6H34A4 4 0 0 1 38 10V54` then the torn edge
  /// back to `12 54`, `V10A4 4 0 0 1 16 6Z`.
  static const double paperCornerRadius = 4;
  static const Offset paperTopStart = Offset(16, 6);
  static const Offset paperTopEnd = Offset(34, 6);
  static const Offset paperRightTop = Offset(38, 10);
  static const List<Offset> paperTornEdge = [
    Offset(38, 54),
    Offset(34.75, 51),
    Offset(31.5, 54),
    Offset(28.25, 51),
    Offset(25, 54),
    Offset(21.75, 51),
    Offset(18.5, 54),
    Offset(15.25, 51),
    Offset(12, 54),
  ];
  static const Offset paperLeftTop = Offset(12, 10);
  static const double paperStrokeWidth = 2.4;

  /// Centre of the paper's box, the origin of its `pop` scale.
  static const Offset paperCenter = Offset(25, 30);

  /// `pop`: rises 8 units and grows from 90 %.
  static const double paperRise = 8;
  static const double paperStartScale = 0.9;

  /// Printed lines at full width (`.ln`), scaled from their start edge.
  static const List<Rect> lines = [
    Rect.fromLTWH(17, 15, 16, 3),
    Rect.fromLTWH(17, 23, 16, 3),
    Rect.fromLTWH(17, 31, 11, 3),
  ];
  static const double lineRadius = 1.5;

  /// `shrink`: lines end at 55 % of their width (the static mark's 9 and 6
  /// units).
  static const double lineShrunkScale = 0.55;

  /// Scan beam (`.beam`) and its 40-unit travel.
  static const Rect beam = Rect.fromLTWH(13, 9, 24, 1.6);
  static const double beamRadius = 0.8;
  static const double beamTravel = 40;

  /// `scan` keyframes: fully visible between 12 % and 88 %.
  static const double beamFadeIn = 0.12;
  static const double beamFadeOut = 0.88;

  /// Data pixels (`.px`) in the order of `SplashTimings.pixels`, with their
  /// final opacities.
  static const List<Rect> pixels = [
    Rect.fromLTWH(42, 14.5, 4, 4),
    Rect.fromLTWH(48, 14.5, 4, 4),
    Rect.fromLTWH(54, 14.5, 4, 4),
    Rect.fromLTWH(42, 22.5, 4, 4),
    Rect.fromLTWH(48, 22.5, 4, 4),
    Rect.fromLTWH(42, 30.5, 4, 4),
  ];
  static const List<double> pixelOpacities = [1, 0.7, 0.4, 1, 0.7, 1];
  static const double pixelRadius = 1;

  /// `px`: pixels slide 10 units in and grow from 20 %.
  static const double pixelSlide = 10;
  static const double pixelStartScale = 0.2;
}
