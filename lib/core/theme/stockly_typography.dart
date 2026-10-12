import 'package:flutter/material.dart';

/// Bundled font families (design §7.5, SIL OFL).
abstract final class FontFamilies {
  static const String display = 'ReadexPro';
  static const String body = 'IBMPlexSansArabic';
  static const String mono = 'IBMPlexMono';

  /// Mixed Arabic and Latin text always renders.
  static const List<String> displayFallback = [body, display];
  static const List<String> bodyFallback = [display];
}

/// Brand text styles beyond the Material `TextTheme`. Colors are applied
/// from `StocklyColors`, never inside these styles.
@immutable
final class StocklyTypography extends ThemeExtension<StocklyTypography> {
  const new({
    required this.wordmark,
    required this.tagline,
    required this.numberLarge,
    required this.numberMedium,
    required this.numberSmall,
    required this.code,
  });

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static const StocklyTypography standard = StocklyTypography(
    wordmark: TextStyle(
      fontFamily: FontFamilies.display,
      fontFamilyFallback: FontFamilies.displayFallback,
      fontSize: 30,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    tagline: TextStyle(
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
      height: 1.5,
    ),
    numberLarge: TextStyle(
      fontFamily: FontFamilies.display,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      fontFeatures: _tabular,
    ),
    numberMedium: TextStyle(
      fontFamily: FontFamilies.mono,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    ),
    numberSmall: TextStyle(
      fontFamily: FontFamilies.mono,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      fontFeatures: _tabular,
    ),
    code: TextStyle(
      fontFamily: FontFamilies.mono,
      fontSize: 12.5,
      fontWeight: FontWeight.w400,
    ),
  );

  /// ReadexPro 30/700, letter spacing −0.01 em.
  final TextStyle wordmark;

  /// IBM Plex Sans Arabic 13.5/400.
  final TextStyle tagline;

  /// Dashboard numbers.
  final TextStyle numberLarge;

  /// Prices and quantities.
  final TextStyle numberMedium;
  final TextStyle numberSmall;

  /// Barcodes, invoice numbers.
  final TextStyle code;

  /// The Material text theme from the brand sheet's sizes.
  static TextTheme textTheme() => const TextTheme(
    displaySmall: TextStyle(
      fontFamily: FontFamilies.display,
      fontFamilyFallback: FontFamilies.displayFallback,
      fontSize: 34,
      fontWeight: FontWeight.w600,
    ),
    headlineMedium: TextStyle(
      fontFamily: FontFamilies.display,
      fontFamilyFallback: FontFamilies.displayFallback,
      fontSize: 28,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      fontFamily: FontFamilies.display,
      fontFamilyFallback: FontFamilies.displayFallback,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      fontSize: 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: TextStyle(
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.6,
    ),
    bodySmall: TextStyle(
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      fontSize: 13,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      fontFamily: FontFamilies.body,
      fontFamilyFallback: FontFamilies.bodyFallback,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  );

  @override
  StocklyTypography copyWith({
    TextStyle? wordmark,
    TextStyle? tagline,
    TextStyle? numberLarge,
    TextStyle? numberMedium,
    TextStyle? numberSmall,
    TextStyle? code,
  }) => StocklyTypography(
    wordmark: wordmark ?? this.wordmark,
    tagline: tagline ?? this.tagline,
    numberLarge: numberLarge ?? this.numberLarge,
    numberMedium: numberMedium ?? this.numberMedium,
    numberSmall: numberSmall ?? this.numberSmall,
    code: code ?? this.code,
  );

  @override
  StocklyTypography lerp(StocklyTypography? other, double t) {
    if (other == null) {
      return this;
    }
    return StocklyTypography(
      wordmark: TextStyle.lerp(wordmark, other.wordmark, t)!,
      tagline: TextStyle.lerp(tagline, other.tagline, t)!,
      numberLarge: TextStyle.lerp(numberLarge, other.numberLarge, t)!,
      numberMedium: TextStyle.lerp(numberMedium, other.numberMedium, t)!,
      numberSmall: TextStyle.lerp(numberSmall, other.numberSmall, t)!,
      code: TextStyle.lerp(code, other.code, t)!,
    );
  }
}
