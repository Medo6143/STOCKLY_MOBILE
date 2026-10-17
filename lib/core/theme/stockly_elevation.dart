import 'package:flutter/material.dart';
import 'package:stockly/core/theme/stockly_colors.dart';

/// Depth of cards and surfaces (design-refresh brief). Light: soft shadows
/// in `ink` with alpha. Dark: no shadow, a 1 px `line` border and the
/// slightly lighter `raisedSurface`.
///
/// Derived tokens, brand approval pending: level 1 is ink at 6 % alpha,
/// blur 16, offset 4; level 2 is ink at 10 % alpha, blur 28, offset 12,
/// over a tight ink at 4 % alpha, blur 4, offset 1.
@immutable
final class StocklyElevation extends ThemeExtension<StocklyElevation> {
  const new({required this.level1, required this.level2, required this.border});

  factory light(StocklyColors colors) => StocklyElevation(
    level1: [
      BoxShadow(
        color: colors.ink.withValues(alpha: _level1Alpha),
        blurRadius: _level1Blur,
        offset: const Offset(0, _level1Offset),
      ),
    ],
    level2: [
      BoxShadow(
        color: colors.ink.withValues(alpha: _ambientAlpha),
        blurRadius: _ambientBlur,
        offset: const Offset(0, _ambientOffset),
      ),
      BoxShadow(
        color: colors.ink.withValues(alpha: _level2Alpha),
        blurRadius: _level2Blur,
        offset: const Offset(0, _level2Offset),
      ),
    ],
    border: null,
  );

  factory dark(StocklyColors colors) => StocklyElevation(
    level1: const [],
    level2: const [],
    border: BorderSide(color: colors.line),
  );

  static const double _level1Alpha = 0.06;
  static const double _level1Blur = 16;
  static const double _level1Offset = 4;
  static const double _level2Alpha = 0.10;
  static const double _level2Blur = 28;
  static const double _level2Offset = 12;
  static const double _ambientAlpha = 0.04;
  static const double _ambientBlur = 4;
  static const double _ambientOffset = 1;

  /// Cards and list rows.
  final List<BoxShadow> level1;

  /// Hero cards overlapping a header, floating bars.
  final List<BoxShadow> level2;

  /// The outline of a raised surface, `null` when shadows carry the depth.
  final BorderSide? border;

  /// The shadows of [level] 0, 1 or 2.
  List<BoxShadow> shadows(int level) => switch (level) {
    <= 0 => const [],
    1 => level1,
    _ => level2,
  };

  @override
  StocklyElevation copyWith({
    List<BoxShadow>? level1,
    List<BoxShadow>? level2,
    BorderSide? border,
  }) => StocklyElevation(
    level1: level1 ?? this.level1,
    level2: level2 ?? this.level2,
    border: border ?? this.border,
  );

  @override
  StocklyElevation lerp(StocklyElevation? other, double t) {
    if (other == null) {
      return this;
    }
    final border = this.border;
    final otherBorder = other.border;
    return StocklyElevation(
      level1: BoxShadow.lerpList(level1, other.level1, t) ?? const [],
      level2: BoxShadow.lerpList(level2, other.level2, t) ?? const [],
      border: border == null || otherBorder == null
          ? (t < 0.5 ? border : otherBorder)
          : BorderSide.lerp(border, otherBorder, t),
    );
  }
}
