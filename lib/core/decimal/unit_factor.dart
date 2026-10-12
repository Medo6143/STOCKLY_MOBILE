import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/decimal/decimal_wire.dart';

/// Base units in one product unit: exactly 6 decimals on the wire, `> 0`.
@immutable
final class UnitFactor implements Comparable<UnitFactor> {
  const new _(this.value);

  /// Parses an API factor string. Throws [FormatException].
  factory fromApi(String raw) =>
      UnitFactor._(DecimalWire.parse(raw, maxScale: scale));

  /// Wraps a value with at most [scale] decimals (from `DecimalInputParser`).
  factory fromDecimal(Decimal value) {
    if (value.scale > scale) {
      throw ArgumentError.value(value, 'value', 'more than $scale decimals');
    }
    return UnitFactor._(value);
  }

  static const int scale = 6;

  final Decimal value;

  /// Exactly 6 decimals, never rounded.
  String toApi() => DecimalWire.format(value, scale: scale);

  @override
  int compareTo(UnitFactor other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is UnitFactor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toApi();
}
