import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/decimal/decimal_wire.dart';
import 'package:stockly/core/decimal/quantity.dart';

/// An EGP amount: exactly 2 decimals on the wire, `>= 0` in requests.
@immutable
final class Money implements Comparable<Money> {
  const new _(this.value);

  /// Parses an API money string. Throws [FormatException].
  factory fromApi(String raw) =>
      Money._(DecimalWire.parse(raw, maxScale: scale));

  /// Wraps a value with at most [scale] decimals (from `DecimalInputParser`).
  factory fromDecimal(Decimal value) {
    if (value.scale > scale) {
      throw ArgumentError.value(value, 'value', 'more than $scale decimals');
    }
    return Money._(value);
  }

  static const int scale = 2;
  static final Money zero = Money._(Decimal.zero);

  final Decimal value;

  /// Exactly 2 decimals, never rounded.
  String toApi() => DecimalWire.format(value, scale: scale);

  Money operator +(Money other) => Money._(value + other.value);

  /// Price × quantity, for previews only: the server's value wins.
  Decimal times(Quantity quantity) => value * quantity.value;

  @override
  int compareTo(Money other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Money && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toApi();
}
