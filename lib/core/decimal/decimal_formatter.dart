import 'package:decimal/decimal.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

/// Locale-independent, exact number display with Western digits in both
/// languages (design §5.4). No `double`, no `NumberFormat` on `num`.
abstract final class DecimalFormatter {
  static const int _groupSize = 3;
  static const String _groupSeparator = ',';
  static const String _point = '.';
  static const String _minus = '-';
  static const String _plus = '+';
  static final Decimal _hundred = Decimal.fromInt(100);
  static final RegExp _trailingZeros = RegExp(r'0+$');

  /// `1,250.00`
  static String formatMoney(Money money) {
    final fixed = money.value.toStringAsFixed(Money.scale);
    final negative = fixed.startsWith(_minus);
    final unsigned = negative ? fixed.substring(1) : fixed;
    final parts = unsigned.split(_point);
    final sign = negative ? _minus : '';
    return '$sign${_group(parts.first)}$_point${parts.last}';
  }

  /// `24`, `1.5`, `-2`
  static String formatQuantity(Quantity quantity) => _trim(quantity.value);

  /// `+24`, `-2`, `0`: a stock change with its sign.
  static String formatSignedQuantity(Quantity quantity) {
    final text = formatQuantity(quantity);
    return quantity.value > Decimal.zero ? '$_plus$text' : text;
  }

  /// `3`, `2.5`
  static String formatFactor(UnitFactor factor) => _trim(factor.value);

  /// `85` for `0.85`.
  static String formatConfidencePercent(MatchConfidence confidence) =>
      (confidence.value * _hundred).toStringAsFixed(0);

  static String _trim(Decimal value) {
    final text = value.toString();
    if (!text.contains(_point)) {
      return text;
    }
    final trimmed = text.replaceFirst(_trailingZeros, '');
    return trimmed.endsWith(_point)
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % _groupSize == 0) {
        buffer.write(_groupSeparator);
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
