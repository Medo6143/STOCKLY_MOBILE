import 'package:flutter/material.dart';

/// 4-based spacing scale (design §7.2, approved at checkpoint 2). Widgets use
/// it only through `EdgeInsetsDirectional`.
@immutable
final class StocklySpacing extends ThemeExtension<StocklySpacing> {
  const new({
    this.xxs = 4,
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 20,
    this.xl = 24,
    this.xxl = 32,
    this.xxxl = 40,
    this.huge = 48,
  });

  static const StocklySpacing standard = StocklySpacing();

  final double xxs;
  final double xs;
  final double sm;

  /// Screen side gutter.
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double huge;

  @override
  StocklySpacing copyWith({
    double? xxs,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? xxxl,
    double? huge,
  }) => StocklySpacing(
    xxs: xxs ?? this.xxs,
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xxl: xxl ?? this.xxl,
    xxxl: xxxl ?? this.xxxl,
    huge: huge ?? this.huge,
  );

  @override
  StocklySpacing lerp(StocklySpacing? other, double t) => this;
}
