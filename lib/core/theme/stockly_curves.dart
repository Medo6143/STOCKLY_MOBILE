import 'package:flutter/animation.dart';

/// Every easing curve of the app's motion, named in one place. Derived
/// (design-refresh brief), brand approval pending. Splash curves stay in
/// `SplashCurves`.
abstract final class StocklyCurves {
  /// Items and cards entering the screen.
  static const Curve entrance = Curves.easeOutCubic;

  /// Pushes: the new page settles in.
  static const Curve push = Curves.easeOutCubic;

  /// Fade-through between tabs: the old tab fades out in the first part,
  /// the new one fades and scales in after it.
  static const Curve fadeThroughOut = Interval(0, 0.35, curve: Curves.easeIn);
  static const Curve fadeThroughIn = Interval(
    0.35,
    1,
    curve: Curves.easeOutCubic,
  );

  /// Press feedback on buttons and cards.
  static const Curve press = Curves.easeOut;

  /// Dashboard numbers counting up.
  static const Curve counter = Curves.easeOutCubic;

  /// The success check: the circle pops, then the tick draws.
  static const Curve successPop = Curves.easeOutBack;
  static const Curve successTick = Interval(0.4, 1, curve: Curves.easeOutCubic);

  /// Colour changes of chips and pills.
  static const Curve color = Curves.easeInOut;
}

/// Sizes and factors used by the motion, so animations hold no literals.
/// Derived (design-refresh brief), brand approval pending.
abstract final class MotionGeometry {
  /// Entering items rise this many logical pixels while fading in.
  static const double entranceRise = 8;

  /// Only the first items of a list wait for their turn; later ones enter
  /// with the last of them.
  static const int maxStaggeredItems = 10;

  /// Pressed buttons and cards shrink to this scale.
  static const double pressedScale = 0.97;

  /// A tab fading in starts at this scale.
  static const double fadeThroughScale = 0.96;

  /// A pushed page starts this fraction of its width towards the end edge.
  static const double pushSlide = 0.12;

  /// A page under a push moves this fraction towards the start edge.
  static const double pushParallax = 0.04;

  /// Counters move in this many even steps from zero to their value.
  static const int counterSteps = 60;

  /// The success circle starts at this scale.
  static const double successStartScale = 0.4;
}
