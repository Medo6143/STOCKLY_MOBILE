import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/decimal_input_parser.dart';

DecimalInputResult _parse(
  String raw, {
  int maxScale = 2,
  DecimalSign sign = DecimalSign.nonNegative,
}) => DecimalInputParser.parse(raw, maxScale: maxScale, sign: sign);

DecimalInputValid _valid(String value) =>
    DecimalInputValid(Decimal.parse(value));

void main() {
  test('parse_WesternDigits_Valid', () {
    expect(_parse('12.5'), _valid('12.5'));
  });

  test('parse_ArabicIndicDigits_Normalized', () {
    expect(_parse('١٢٫٥'), _valid('12.5'));
    expect(_parse('٠١٢٣٤٥٦٧٨٩'), _valid('123456789'));
  });

  test('parse_ExtendedArabicIndicDigits_Normalized', () {
    expect(_parse('۱۲۳۴'), _valid('1234'));
    expect(_parse('۰٫۵'), _valid('0.5'));
  });

  test('parse_CommaOnAKeypadWithCommaDecimal_InvalidNeverGuessed', () {
    // "1,5" meant one and a half: dropping the comma would record 15.
    expect(_parse('1,5'), isA<DecimalInputInvalidFormat>());
    expect(_parse('12,50'), isA<DecimalInputInvalidFormat>());
    expect(_parse('1,250', maxScale: 3), isA<DecimalInputInvalidFormat>());
  });

  test('parse_GroupingSeparators_Invalid', () {
    expect(_parse('1,250.50'), isA<DecimalInputInvalidFormat>());
    expect(_parse('١٬٢٥٠٫٥٠'), isA<DecimalInputInvalidFormat>());
    expect(_parse('1 250'), isA<DecimalInputInvalidFormat>());
  });

  test('parse_SurroundingSpaces_Trimmed', () {
    expect(_parse(' 12.5 '), _valid('12.5'));
    expect(_parse('\t١٢٫٥\n'), _valid('12.5'));
  });

  test('parse_Empty_ReturnsEmpty', () {
    expect(_parse(''), isA<DecimalInputEmpty>());
    expect(_parse('   '), isA<DecimalInputEmpty>());
  });

  test('parse_TooManyDecimals_NeverRounded', () {
    expect(_parse('1.005'), isA<DecimalInputTooManyDecimals>());
    expect(_parse('1.0000', maxScale: 3), isA<DecimalInputTooManyDecimals>());
    expect(_parse('1.000', maxScale: 3), _valid('1'));
  });

  test('parse_InvalidFormat_Rejected', () {
    expect(_parse('1.2.3'), isA<DecimalInputInvalidFormat>());
    expect(_parse('abc'), isA<DecimalInputInvalidFormat>());
    expect(_parse('--1'), isA<DecimalInputInvalidFormat>());
    expect(_parse('1.'), isA<DecimalInputInvalidFormat>());
  });

  test('parse_MoreThanSeventeenIntegerDigits_OutOfRange', () {
    expect(_parse('123456789012345678'), isA<DecimalInputOutOfRange>());
    expect(
      _parse('-123456789012345678', sign: DecimalSign.any),
      isA<DecimalInputOutOfRange>(),
    );
    expect(_parse('12345678901234567'), _valid('12345678901234567'));
  });

  test('parse_SignRules', () {
    expect(_parse('-1'), isA<DecimalInputNegativeNotAllowed>());
    expect(_parse('0'), _valid('0'));
    expect(
      _parse('-1', sign: DecimalSign.positive),
      isA<DecimalInputNegativeNotAllowed>(),
    );
    expect(
      _parse('0', sign: DecimalSign.positive),
      isA<DecimalInputZeroNotAllowed>(),
    );
    expect(_parse('0.5', sign: DecimalSign.positive), _valid('0.5'));
    expect(_parse('-2.5', sign: DecimalSign.any), _valid('-2.5'));
    expect(_parse('0', sign: DecimalSign.any), _valid('0'));
  });

  test('DecimalInputValid_Equality_ByValue', () {
    expect(_valid('1.0'), _valid('1'));
    expect(_valid('1.0').hashCode, _valid('1').hashCode);
  });
}
