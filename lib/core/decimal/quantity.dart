import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/decimal/decimal_wire.dart';

/// A quantity in a product unit: exactly 3 decimals on the wire. Responses
/// may be negative (stock below zero).
@immutable
final class Quantity implements Comparable<Quantity> {
  const new _(this.value);

  /// Parses an API quantity string. Throws [FormatException].
  factory fromApi(String raw) =>
      Quantity._(DecimalWire.parse(raw, maxScale: scale));

  /// Wraps a value with at most [scale] decimals (from `DecimalInputParser`).
  factory fromDecimal(Decimal value) {
    if (value.scale > scale) {
      throw ArgumentError.value(value, 'value', 'more than $scale decimals');
    }
    return Quantity._(value);
  }

  static const int scale = 3;
  static final Quantity zero = Quantity._(Decimal.zero);
  static final Quantity one = Quantity._(Decimal.one);

  /// This quantity plus [other].
  Quantity operator +(Quantity other) => Quantity._(value + other.value);

  final Decimal value;

  bool get isNegative => value < Decimal.zero;

  /// Exactly 3 decimals, never rounded.
  String toApi() => DecimalWire.format(value, scale: scale);

  @override
  int compareTo(Quantity other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Quantity && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toApi();
}
