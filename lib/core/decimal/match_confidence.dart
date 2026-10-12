import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/decimal/decimal_wire.dart';

/// AI match confidence: 2 decimals, `0.00`–`1.00`. Never sent.
@immutable
final class MatchConfidence implements Comparable<MatchConfidence> {
  const new _(this.value);

  /// Parses an API confidence string. Throws [FormatException] when the
  /// string is malformed or outside `0.00`–`1.00`.
  factory fromApi(String raw) {
    final value = DecimalWire.parse(raw, maxScale: scale);
    if (value < Decimal.zero || value > Decimal.one) {
      throw FormatException('Confidence outside 0.00-1.00', raw);
    }
    return MatchConfidence._(value);
  }

  static const int scale = 2;

  final Decimal value;

  @override
  int compareTo(MatchConfidence other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is MatchConfidence && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => DecimalWire.format(value, scale: scale);
}
