import 'package:flutter/material.dart';
import 'package:stockly/core/theme/stockly_colors.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/theme/stockly_radii.dart';
import 'package:stockly/core/theme/stockly_spacing.dart';
import 'package:stockly/core/theme/stockly_typography.dart';
import 'package:stockly/core/theme/tokens.dart';

/// Material themes built from the brand extensions (design §7.1), so
/// Material widgets match the tokens.
abstract final class AppTheme {
  static ThemeData light() => _build(StocklyColors.light, Brightness.light);

  static ThemeData dark() => _build(StocklyColors.dark, Brightness.dark);

  static ThemeData _build(StocklyColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.mint,
      onPrimary: colors.onMint,
      primaryContainer: colors.mintSoft,
      onPrimaryContainer: colors.ink,
      secondary: colors.ink,
      onSecondary: colors.surface,
      surface: colors.surface,
      onSurface: colors.ink,
      onSurfaceVariant: colors.muted,
      outline: colors.line,
      outlineVariant: colors.line,
      error: colors.danger,
      onError: Tokens.white,
    );
    final textTheme = StocklyTypography.textTheme().apply(
      bodyColor: colors.ink,
      displayColor: colors.ink,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      extensions: [
        colors,
        StocklySpacing.standard,
        StocklyRadii.standard,
        StocklyDurations.standard,
        StocklyTypography.standard,
      ],
    );
  }
}

/// Short access to the brand extensions.
extension StocklyThemeX on BuildContext {
  StocklyColors get colors => Theme.of(this).extension<StocklyColors>()!;
  StocklySpacing get spacing => Theme.of(this).extension<StocklySpacing>()!;
  StocklyRadii get radii => Theme.of(this).extension<StocklyRadii>()!;
  StocklyDurations get durations =>
      Theme.of(this).extension<StocklyDurations>()!;
  StocklyTypography get typo => Theme.of(this).extension<StocklyTypography>()!;
}
