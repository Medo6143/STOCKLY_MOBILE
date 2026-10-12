import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/decimal_json_converters.dart';
import 'package:stockly/core/decimal/decimal_wire.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

void main() {
  group('DecimalWire.parse', () {
    test('parse_ContractString_ReturnsExactValue', () {
      expect(DecimalWire.parse('125.50', maxScale: 2), Decimal.parse('125.5'));
      expect(DecimalWire.parse('-2.000', maxScale: 3), Decimal.parse('-2'));
    });

    test('parse_SeventeenIntegerDigits_Accepted', () {
      expect(
        DecimalWire.parse('12345678901234567.00', maxScale: 2),
        Decimal.parse('12345678901234567'),
      );
    });

    for (final raw in [
      '123456789012345678.00',
      '1e5',
      ' 1.00',
      '1.',
      '.5',
      '+1.00',
      '1,250.00',
      '',
      'abc',
    ]) {
      test('parse_Malformed "$raw"_ThrowsFormatException', () {
        expect(
          () => DecimalWire.parse(raw, maxScale: 2),
          throwsFormatException,
        );
      });
    }

    test('parse_TooManyDecimals_ThrowsFormatException', () {
      expect(
        () => DecimalWire.parse('1.234', maxScale: 2),
        throwsFormatException,
      );
    });
  });

  group('DecimalWire.format', () {
    test('format_PadsToScale', () {
      expect(DecimalWire.format(Decimal.parse('1.5'), scale: 3), '1.500');
      expect(DecimalWire.format(Decimal.parse('-2'), scale: 3), '-2.000');
    });

    test('format_MoreDecimalsThanScale_ThrowsInsteadOfRounding', () {
      expect(
        () => DecimalWire.format(Decimal.parse('1.005'), scale: 2),
        throwsArgumentError,
      );
    });
  });

  group('value types', () {
    test('Money_RoundTrip_ExactlyTwoDecimals', () {
      final money = Money.fromApi('125.50');
      expect(money.toApi(), '125.50');
      expect(Money.fromApi('3').toApi(), '3.00');
      expect(money + Money.fromApi('0.50'), Money.fromApi('126.00'));
      expect(Money.zero.toApi(), '0.00');
    });

    test('Money_Times_IsExact', () {
      expect(
        Money.fromApi('0.10').times(Quantity.fromApi('3.000')),
        Decimal.parse('0.3'),
      );
    });

    test('Money_FromDecimalWithThreeDecimals_Throws', () {
      expect(
        () => Money.fromDecimal(Decimal.parse('1.001')),
        throwsArgumentError,
      );
    });

    test('Quantity_RoundTrip_ExactlyThreeDecimals', () {
      final quantity = Quantity.fromApi('-2.000');
      expect(quantity.toApi(), '-2.000');
      expect(quantity.isNegative, isTrue);
      expect(Quantity.fromDecimal(Decimal.parse('1.5')).toApi(), '1.500');
      expect(Quantity.zero.isNegative, isFalse);
      expect(
        () => Quantity.fromDecimal(Decimal.parse('1.0001')),
        throwsArgumentError,
      );
    });

    test('UnitFactor_RoundTrip_ExactlySixDecimals', () {
      expect(UnitFactor.fromApi('3.000000').toApi(), '3.000000');
      expect(UnitFactor.fromDecimal(Decimal.parse('2.5')).toApi(), '2.500000');
      expect(() => UnitFactor.fromApi('1.0000001'), throwsFormatException);
      expect(
        () => UnitFactor.fromDecimal(Decimal.parse('1.0000001')),
        throwsArgumentError,
      );
    });

    test('MatchConfidence_OutsideZeroToOne_Throws', () {
      expect(MatchConfidence.fromApi('0.85').toString(), '0.85');
      expect(() => MatchConfidence.fromApi('1.01'), throwsFormatException);
      expect(() => MatchConfidence.fromApi('-0.01'), throwsFormatException);
    });

    test('ValueTypes_CompareAndEquality_ByValue', () {
      expect(Money.fromApi('1.00'), Money.fromApi('1'));
      expect(Money.fromApi('1.00').hashCode, Money.fromApi('1').hashCode);
      expect(
        Money.fromApi('1.00').compareTo(Money.fromApi('2.00')),
        isNegative,
      );
      expect(
        Quantity.fromApi('2.000').compareTo(Quantity.fromApi('1')),
        isPositive,
      );
      expect(
        UnitFactor.fromApi('1.000000').compareTo(UnitFactor.fromApi('1')),
        0,
      );
      expect(MatchConfidence.fromApi('0.50'), MatchConfidence.fromApi('0.5'));
      expect(
        MatchConfidence.fromApi('0.50').compareTo(MatchConfidence.fromApi('1')),
        isNegative,
      );
      expect(Quantity.fromApi('1').hashCode, Quantity.fromApi('1.0').hashCode);
      expect(
        UnitFactor.fromApi('1').hashCode,
        UnitFactor.fromApi('1.0').hashCode,
      );
      expect(
        MatchConfidence.fromApi('1').hashCode,
        MatchConfidence.fromApi('1.00').hashCode,
      );
      expect(Money.fromApi('1').toString(), '1.00');
      expect(Quantity.fromApi('1').toString(), '1.000');
      expect(UnitFactor.fromApi('1').toString(), '1.000000');
    });
  });

  group('JSON converters', () {
    test('Converters_RoundTrip_AsStrings', () {
      expect(const MoneyConverter().toJson(Money.fromApi('1.5')), '1.50');
      expect(const MoneyConverter().fromJson('1.50'), Money.fromApi('1.5'));
      expect(const NullableMoneyConverter().fromJson(null), isNull);
      expect(const NullableMoneyConverter().toJson(null), isNull);
      expect(
        const NullableMoneyConverter().fromJson('2.00'),
        Money.fromApi('2'),
      );
      expect(const NullableMoneyConverter().toJson(Money.fromApi('2')), '2.00');
      expect(const QuantityConverter().fromJson('1.500').toApi(), '1.500');
      expect(const QuantityConverter().toJson(Quantity.fromApi('1')), '1.000');
      expect(
        const UnitFactorConverter().fromJson('3.000000').toApi(),
        '3.000000',
      );
      expect(
        const UnitFactorConverter().toJson(UnitFactor.fromApi('3')),
        '3.000000',
      );
      expect(
        const MatchConfidenceConverter().fromJson('0.85').toString(),
        '0.85',
      );
      expect(
        const MatchConfidenceConverter().toJson(MatchConfidence.fromApi('1')),
        '1.00',
      );
      expect(const NullableMatchConfidenceConverter().fromJson(null), isNull);
      expect(const NullableMatchConfidenceConverter().toJson(null), isNull);
      expect(
        const NullableMatchConfidenceConverter().fromJson('0.10').toString(),
        '0.10',
      );
      expect(
        const NullableMatchConfidenceConverter().toJson(
          MatchConfidence.fromApi('0.1'),
        ),
        '0.10',
      );
    });

    test('Converters_MalformedString_ThrowFormatException', () {
      expect(
        () => const MoneyConverter().fromJson('12.5.0'),
        throwsFormatException,
      );
      expect(
        () => const QuantityConverter().fromJson('1.0000'),
        throwsFormatException,
      );
    });
  });
}
