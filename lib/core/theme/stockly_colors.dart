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
    );
  }
}
