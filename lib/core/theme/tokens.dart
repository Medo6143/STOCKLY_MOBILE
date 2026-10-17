import 'dart:ui';

/// Raw brand values from `brand/stockly-brand.html` (design §7.1). The only
/// file in the app with color literals.
abstract final class Tokens {
  // Light theme (`:root`).
  static const Color lightBackground = Color(0xFFF3F7F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF12233D);
  static const Color lightMuted = Color(0xFF5B6B7E);
  static const Color lightLine = Color(0xFFDCE5E1);
  static const Color lightMint = Color(0xFF22B57E);
  static const Color lightMintSoft = Color(0xFFD7F3E7);

  // Dark theme (`prefers-color-scheme: dark`).
  static const Color darkBackground = Color(0xFF0B1626);
  static const Color darkSurface = Color(0xFF13233A);
  static const Color darkInk = Color(0xFFE6EEF5);
  static const Color darkMuted = Color(0xFF93A3B5);
  static const Color darkLine = Color(0xFF1F3049);
  static const Color darkMint = Color(0xFF3DDC9B);
  static const Color darkMintSoft = Color(0xFF123B32);

  // Shared swatches.
  static const Color navy = Color(0xFF12233D);
  static const Color danger = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF2A33A);
  static const Color white = Color(0xFFFFFFFF);

  // Derived (approved at checkpoint 2): ink on mint.
  static const Color lightOnMint = Color(0xFF12233D);
  static const Color darkOnMint = Color(0xFF0B1626);

  // Derived (approved at checkpoint 2): danger at 12% and warning at 16%
  // alpha, composed over the surface by `StocklyColors`.
  static const double dangerSoftAlpha = 0.12;
  static const double warningSoftAlpha = 0.16;

  // Derived (design-refresh brief, brand approval pending): the mint glow
  // on hero headers, the muted text on them, the dark raised surface (ink
  // at 4% over the surface) and the skeleton shimmer highlight.
  static const double lightHeroGlowAlpha = 0.30;
  static const double darkHeroGlowAlpha = 0.18;
  static const double onHeroMutedAlpha = 0.72;
  static const double heroDecorationAlpha = 0.07;
  static const double darkRaisedSurfaceAlpha = 0.04;
  static const double shimmerHighlightAlpha = 0.55;

  // Splash mark (`--s-paper`, `--s-ink`, `--s-mint`).
  static const Color lightMarkPaper = Color(0xFFFFFFFF);
  static const Color lightMarkInk = Color(0xFF12233D);
  static const Color lightMarkMint = Color(0xFF22B57E);
  static const Color darkMarkPaper = Color(0xFF13233A);
  static const Color darkMarkInk = Color(0xFFE6EEF5);
  static const Color darkMarkMint = Color(0xFF3DDC9B);
}
