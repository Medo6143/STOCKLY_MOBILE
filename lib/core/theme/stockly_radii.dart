import 'package:flutter/material.dart';

/// Corner radii from the brand sheet (design §7.3).
@immutable
final class StocklyRadii extends ThemeExtension<StocklyRadii> {
  const new({
    this.xs = 6,
    this.sm = 9,
    this.md = 14,
    this.lg = 16,
    this.xl = 20,
    this.xxl = 24,
    this.pill = 999,
  });

  static const StocklyRadii standard = StocklyRadii();

  /// Code chips.
  final double xs;

  /// Small app icon.
  final double sm;

  /// Swatches, cards.
  final double md;

  /// Tiles, sheets.
  final double lg;

  /// App icon.
  final double xl;

  /// Hero cards and sheets. Derived (design-refresh brief), brand approval
  /// pending.
  final double xxl;

  /// Segmented buttons, chips.
  final double pill;

  BorderRadiusDirectional circular(double radius) =>
      BorderRadiusDirectional.all(Radius.circular(radius));

  @override
  StocklyRadii copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? pill,
  }) => StocklyRadii(
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xxl: xxl ?? this.xxl,
    pill: pill ?? this.pill,
  );

  @override
  StocklyRadii lerp(StocklyRadii? other, double t) => this;
}
