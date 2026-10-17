import 'package:flutter/material.dart';
import 'package:stockly/core/theme/tokens.dart';

/// Brand colors for one theme (design §7.1).
@immutable
final class StocklyColors extends ThemeExtension<StocklyColors> {
  const new({
    required this.background,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.mint,
    required this.mintSoft,
    required this.navy,
    required this.danger,
    required this.warning,
    required this.onMint,
    required this.dangerSoft,
    required this.warningSoft,
    required this.markPaper,
    required this.markInk,
    required this.markMint,
    required this.raisedSurface,
    required this.heroStart,
    required this.heroEnd,
    required this.heroGlow,
    required this.heroDecoration,
    required this.onHero,
    required this.onHeroMuted,
    required this.shimmerHighlight,
  });

  static final StocklyColors light = StocklyColors(
    background: Tokens.lightBackground,
    surface: Tokens.lightSurface,
    ink: Tokens.lightInk,
    muted: Tokens.lightMuted,
    line: Tokens.lightLine,
    mint: Tokens.lightMint,
    mintSoft: Tokens.lightMintSoft,
    navy: Tokens.navy,
    danger: Tokens.danger,
    warning: Tokens.warning,
    onMint: Tokens.lightOnMint,
    dangerSoft: _soft(
      Tokens.danger,
      Tokens.dangerSoftAlpha,
      Tokens.lightSurface,
    ),
    warningSoft: _soft(
      Tokens.warning,
      Tokens.warningSoftAlpha,
      Tokens.lightSurface,
    ),
    markPaper: Tokens.lightMarkPaper,
    markInk: Tokens.lightMarkInk,
    markMint: Tokens.lightMarkMint,
    raisedSurface: Tokens.lightSurface,
    heroStart: Tokens.navy,
    heroEnd: Tokens.lightInk,
    heroGlow: Tokens.lightMint.withValues(alpha: Tokens.lightHeroGlowAlpha),
    heroDecoration: Tokens.white.withValues(alpha: Tokens.heroDecorationAlpha),
    onHero: Tokens.white,
    onHeroMuted: Tokens.white.withValues(alpha: Tokens.onHeroMutedAlpha),
    shimmerHighlight: Tokens.lightSurface.withValues(
      alpha: Tokens.shimmerHighlightAlpha,
    ),
  );

  static final StocklyColors dark = StocklyColors(
    background: Tokens.darkBackground,
    surface: Tokens.darkSurface,
    ink: Tokens.darkInk,
    muted: Tokens.darkMuted,
    line: Tokens.darkLine,
    mint: Tokens.darkMint,
    mintSoft: Tokens.darkMintSoft,
    navy: Tokens.navy,
    danger: Tokens.danger,
    warning: Tokens.warning,
    onMint: Tokens.darkOnMint,
    dangerSoft: _soft(
      Tokens.danger,
      Tokens.dangerSoftAlpha,
      Tokens.darkSurface,
    ),
    warningSoft: _soft(
      Tokens.warning,
      Tokens.warningSoftAlpha,
      Tokens.darkSurface,
    ),
    markPaper: Tokens.darkMarkPaper,
    markInk: Tokens.darkMarkInk,
    markMint: Tokens.darkMarkMint,
    raisedSurface: _soft(
      Tokens.darkInk,
      Tokens.darkRaisedSurfaceAlpha,
      Tokens.darkSurface,
    ),
    heroStart: Tokens.darkBackground,
    heroEnd: Tokens.darkSurface,
    heroGlow: Tokens.darkMint.withValues(alpha: Tokens.darkHeroGlowAlpha),
    heroDecoration: Tokens.darkInk.withValues(
      alpha: Tokens.heroDecorationAlpha,
    ),
    onHero: Tokens.darkInk,
    onHeroMuted: Tokens.darkMuted,
    shimmerHighlight: Tokens.darkInk.withValues(
      alpha: Tokens.heroDecorationAlpha,
    ),
  );

  final Color background;
  final Color surface;
  final Color ink;
  final Color muted;
  final Color line;
  final Color mint;
  final Color mintSoft;
  final Color navy;
  final Color danger;
  final Color warning;
  final Color onMint;
  final Color dangerSoft;
  final Color warningSoft;
  final Color markPaper;
  final Color markInk;
  final Color markMint;

  /// Cards: the surface in light, slightly lighter than it in dark.
  final Color raisedSurface;

  /// Hero header gradient: navy → ink (light), background → surface (dark).
  final Color heroStart;
  final Color heroEnd;

  /// The mint glow in the end corner of a hero header.
  final Color heroGlow;

  /// The soft rings drawn on a hero header.
  final Color heroDecoration;

  /// Text and icons on a hero header.
  final Color onHero;
  final Color onHeroMuted;

  /// The moving highlight of a loading skeleton.
  final Color shimmerHighlight;

  /// [color] at [alpha], composed over [surface].
  static Color _soft(Color color, double alpha, Color surface) =>
      Color.alphaBlend(color.withValues(alpha: alpha), surface);

  @override
  StocklyColors copyWith({
    Color? background,
    Color? surface,
    Color? ink,
    Color? muted,
    Color? line,
    Color? mint,
    Color? mintSoft,
    Color? navy,
    Color? danger,
    Color? warning,
    Color? onMint,
    Color? dangerSoft,
    Color? warningSoft,
    Color? markPaper,
    Color? markInk,
    Color? markMint,
    Color? raisedSurface,
    Color? heroStart,
    Color? heroEnd,
    Color? heroGlow,
    Color? heroDecoration,
    Color? onHero,
    Color? onHeroMuted,
    Color? shimmerHighlight,
  }) => StocklyColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    mint: mint ?? this.mint,
    mintSoft: mintSoft ?? this.mintSoft,
    navy: navy ?? this.navy,
    danger: danger ?? this.danger,
    warning: warning ?? this.warning,
    onMint: onMint ?? this.onMint,
    dangerSoft: dangerSoft ?? this.dangerSoft,
    warningSoft: warningSoft ?? this.warningSoft,
    markPaper: markPaper ?? this.markPaper,
    markInk: markInk ?? this.markInk,
    markMint: markMint ?? this.markMint,
    raisedSurface: raisedSurface ?? this.raisedSurface,
    heroStart: heroStart ?? this.heroStart,
    heroEnd: heroEnd ?? this.heroEnd,
    heroGlow: heroGlow ?? this.heroGlow,
    heroDecoration: heroDecoration ?? this.heroDecoration,
    onHero: onHero ?? this.onHero,
    onHeroMuted: onHeroMuted ?? this.onHeroMuted,
    shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
  );

  @override
  StocklyColors lerp(StocklyColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return StocklyColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      mint: mix(mint, other.mint),
      mintSoft: mix(mintSoft, other.mintSoft),
      navy: mix(navy, other.navy),
      danger: mix(danger, other.danger),
      warning: mix(warning, other.warning),
      onMint: mix(onMint, other.onMint),
      dangerSoft: mix(dangerSoft, other.dangerSoft),
      warningSoft: mix(warningSoft, other.warningSoft),
      markPaper: mix(markPaper, other.markPaper),
      markInk: mix(markInk, other.markInk),
      markMint: mix(markMint, other.markMint),
      raisedSurface: mix(raisedSurface, other.raisedSurface),
      heroStart: mix(heroStart, other.heroStart),
      heroEnd: mix(heroEnd, other.heroEnd),
      heroGlow: mix(heroGlow, other.heroGlow),
      heroDecoration: mix(heroDecoration, other.heroDecoration),
      onHero: mix(onHero, other.onHero),
      onHeroMuted: mix(onHeroMuted, other.onHeroMuted),
      shimmerHighlight: mix(shimmerHighlight, other.shimmerHighlight),
    );
  }
}
