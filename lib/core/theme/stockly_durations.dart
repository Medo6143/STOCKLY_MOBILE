import 'package:flutter/material.dart';

/// Animation and UI durations (design §7.4). Animations read them through
/// `StocklyMotion` so "reduce motion" is respected.
@immutable
final class StocklyDurations extends ThemeExtension<StocklyDurations> {
  const new({
    this.fast = const Duration(milliseconds: 150),
    this.medium = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.searchDebounce = const Duration(milliseconds: 300),
    this.snackbar = const Duration(seconds: 4),
  });

  static const StocklyDurations standard = StocklyDurations();

  /// Press feedback.
  final Duration fast;

  /// Theme transition (brand `.3s`).
  final Duration medium;

  /// Brand `pop` and `up`.
  final Duration slow;
  final Duration searchDebounce;
  final Duration snackbar;

  @override
  StocklyDurations copyWith({
    Duration? fast,
    Duration? medium,
    Duration? slow,
    Duration? searchDebounce,
    Duration? snackbar,
  }) => StocklyDurations(
    fast: fast ?? this.fast,
    medium: medium ?? this.medium,
    slow: slow ?? this.slow,
    searchDebounce: searchDebounce ?? this.searchDebounce,
    snackbar: snackbar ?? this.snackbar,
  );

  @override
  StocklyDurations lerp(StocklyDurations? other, double t) => this;
}

/// One element of the splash timeline.
@immutable
final class SplashStep {
  const new(this.start, this.duration);

  final Duration start;
  final Duration duration;

  Duration get end => start + duration;
}

/// Splash timeline from the brand CSS (design §10.2).
abstract final class SplashTimings {
  /// Length of the controller that drives the mark.
  static const Duration controller = Duration(milliseconds: 2400);

  /// The splash never leaves before this, unless motion is reduced.
  static const Duration minimum = Duration(milliseconds: 1800);

  /// The splash always leaves by this time.
  static const Duration maximum = Duration(milliseconds: 3000);

  static const SplashStep paper = SplashStep(
    Duration.zero,
    Duration(milliseconds: 500),
  );

  static const List<SplashStep> linesIn = [
    SplashStep(Duration.zero, Duration(milliseconds: 350)),
    SplashStep(Duration(milliseconds: 150), Duration(milliseconds: 350)),
    SplashStep(Duration(milliseconds: 250), Duration(milliseconds: 350)),
  ];

  static const SplashStep scanBeam = SplashStep(
    Duration(milliseconds: 450),
    Duration(milliseconds: 750),
  );

  static const List<SplashStep> linesShrink = [
    SplashStep(Duration(milliseconds: 1150), Duration(milliseconds: 450)),
    SplashStep(Duration(milliseconds: 1220), Duration(milliseconds: 450)),
    SplashStep(Duration(milliseconds: 1290), Duration(milliseconds: 450)),
  ];

  /// Pixels in the order (42, 14.5), (48, 14.5), (54, 14.5), (42, 22.5),
  /// (48, 22.5), (42, 30.5).
  static const List<SplashStep> pixels = [
    SplashStep(Duration(milliseconds: 1250), Duration(milliseconds: 350)),
    SplashStep(Duration(milliseconds: 1350), Duration(milliseconds: 350)),
    SplashStep(Duration(milliseconds: 1450), Duration(milliseconds: 350)),
    SplashStep(Duration(milliseconds: 1320), Duration(milliseconds: 350)),
    SplashStep(Duration(milliseconds: 1420), Duration(milliseconds: 350)),
    SplashStep(Duration(milliseconds: 1390), Duration(milliseconds: 350)),
  ];

  static const SplashStep wordmark = SplashStep(
    Duration(milliseconds: 1750),
    Duration(milliseconds: 500),
  );

  static const SplashStep tagline = SplashStep(
    Duration(milliseconds: 1900),
    Duration(milliseconds: 500),
  );

  static const List<Duration> dotDelays = [
    Duration(milliseconds: 2300),
    Duration(milliseconds: 2450),
    Duration(milliseconds: 2600),
  ];

  static const Duration dotCycle = Duration(milliseconds: 1200);
}

/// Splash easing curves from the brand CSS (design §10.2).
abstract final class SplashCurves {
  static const Curve paperPop = Cubic(0.2, 0.8, 0.2, 1.2);
  static const Curve lineIn = Curves.easeOut;
  static const Curve scanBeam = Curves.easeInOut;
  static const Curve lineShrink = Cubic(0.6, 0, 0.3, 1);
  static const Curve pixel = Cubic(0.2, 0.9, 0.3, 1.4);
  static const Curve textUp = Curves.easeOut;
  static const Curve dot = Curves.easeInOut;
}
