/// Splash sizes from the brand CSS (`brand/stockly-brand.html`, `.splash`,
/// `.dots`, `@keyframes up` and `dot`). Design §10.
abstract final class SplashLayout {
  /// `.splash svg`: the mark is drawn 132 logical px wide and high.
  static const double markSize = 132;

  /// `@keyframes up`: wordmark and tagline rise 10 px while fading in.
  static const double textRise = 10;

  /// `.s-tag{max-width:22ch}` at the tagline size, in logical px.
  static const double taglineMaxWidth = 165;

  /// `.dots i`: 6 px dots, 6 px apart, 42 px above the bottom.
  static const double dotSize = 6;
  static const double dotGap = 6;
  static const double dotsBottom = 42;

  /// `@keyframes dot`: opacity at rest and at the peak of a pulse.
  static const double dotRestOpacity = 0.25;
  static const double dotPeakOpacity = 1;
}
