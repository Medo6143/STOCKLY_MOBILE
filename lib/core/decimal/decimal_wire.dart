import 'package:decimal/decimal.dart';

/// Parses and formats the contract's decimal strings (contract §1.2).
abstract final class DecimalWire {
  /// The contract's decimal string pattern.
  static final RegExp pattern = RegExp(r'^-?\d{1,17}(\.\d+)?$');

  /// Parses an API decimal string with at most [maxScale] decimals.
  ///
  /// Throws [FormatException] (mapped to `MalformedResponseFailure`) when the
  /// string does not match the contract.
  static Decimal parse(String raw, {required int maxScale}) {
    if (!pattern.hasMatch(raw)) {
      throw FormatException('Not a contract decimal string', raw);
    }
    if (decimalsOf(raw) > maxScale) {
      throw FormatException('More than $maxScale decimals', raw);
    }
    return Decimal.parse(raw);
  }

  /// Formats [value] with exactly [scale] decimals. Never rounds: values with
  /// more decimals must be rejected earlier (input parser, API parse).
  static String format(Decimal value, {required int scale}) {
    if (value.scale > scale) {
      throw ArgumentError.value(value, 'value', 'more than $scale decimals');
    }
    return value.toStringAsFixed(scale);
  }

  /// The number of digits after the decimal point in [raw].
  static int decimalsOf(String raw) {
    final dot = raw.indexOf('.');
    return dot < 0 ? 0 : raw.length - dot - 1;
  }
}
