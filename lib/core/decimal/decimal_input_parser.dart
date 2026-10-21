import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/decimal/decimal_wire.dart';

/// Which signs a decimal input field accepts.
enum DecimalSign {
  /// `>= 0` (money, thresholds, counts).
  nonNegative,

  /// `> 0` (unit factors, sale quantities).
  positive,

  /// Any sign (stock adjustment `quantityChange`).
  any,
}

/// Outcome of parsing what the user typed (design §5.3).
@immutable
sealed class DecimalInputResult {
  const new();
}

final class DecimalInputValid extends DecimalInputResult {
  const new(this.value);

  final Decimal value;

  @override
  bool operator ==(Object other) =>
      other is DecimalInputValid && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class DecimalInputEmpty extends DecimalInputResult {
  const new();
}

final class DecimalInputInvalidFormat extends DecimalInputResult {
  const new();
}

final class DecimalInputTooManyDecimals extends DecimalInputResult {
  const new();
}

final class DecimalInputNegativeNotAllowed extends DecimalInputResult {
  const new();
}

final class DecimalInputZeroNotAllowed extends DecimalInputResult {
  const new();
}

final class DecimalInputOutOfRange extends DecimalInputResult {
  const new();
}

/// Parses user input exactly: Arabic-Indic digits and the Arabic decimal
/// separator are accepted, extra decimals are rejected and never rounded.
/// Grouping (`,`, `٬`, inner spaces) is rejected too: on a keypad whose
/// decimal key is `,`, "1,5" means one and a half, and dropping the comma
/// would record 15.
abstract final class DecimalInputParser {
  static const int _maxIntegerDigits = 17;

  static const int _arabicIndicZero = 0x0660;
  static const int _extendedArabicIndicZero = 0x06F0;
  static const int _asciiZero = 0x30;
  static const int _digitCount = 10;

  static const String _arabicDecimalSeparator = '٫';
  static const String _minus = '-';
  static const String _point = '.';

  static final RegExp _shape = RegExp(r'^-?\d+(\.\d+)?$');

  static DecimalInputResult parse(
    String raw, {
    required int maxScale,
    required DecimalSign sign,
  }) {
    final normalized = normalize(raw);
    if (normalized.isEmpty) {
      return const DecimalInputEmpty();
    }
    if (!_shape.hasMatch(normalized)) {
      return const DecimalInputInvalidFormat();
    }
    final unsigned = normalized.startsWith(_minus)
        ? normalized.substring(1)
        : normalized;
    if (unsigned.split(_point).first.length > _maxIntegerDigits) {
      return const DecimalInputOutOfRange();
    }
    if (DecimalWire.decimalsOf(normalized) > maxScale) {
      return const DecimalInputTooManyDecimals();
    }
    final value = Decimal.parse(normalized);
    final isNegative = value < Decimal.zero;
    final isZero = value == Decimal.zero;
    return switch (sign) {
      DecimalSign.nonNegative || DecimalSign.positive when isNegative =>
        const DecimalInputNegativeNotAllowed(),
      DecimalSign.positive when isZero => const DecimalInputZeroNotAllowed(),
      _ => DecimalInputValid(value),
    };
  }

  /// Western digits and `.` as decimal separator, surrounding spaces trimmed.
  /// Anything else is kept so the shape check rejects it.
  static String normalize(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.trim().runes) {
      if (rune >= _arabicIndicZero && rune < _arabicIndicZero + _digitCount) {
        buffer.writeCharCode(_asciiZero + rune - _arabicIndicZero);
      } else if (rune >= _extendedArabicIndicZero &&
          rune < _extendedArabicIndicZero + _digitCount) {
        buffer.writeCharCode(_asciiZero + rune - _extendedArabicIndicZero);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString().replaceAll(_arabicDecimalSeparator, _point);
  }
}
