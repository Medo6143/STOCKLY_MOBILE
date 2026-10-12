import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/decimal_formatter.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

void main() {
  test('formatMoney_GroupsThousandsWithTwoDecimals', () {
    expect(DecimalFormatter.formatMoney(Money.fromApi('1250.00')), '1,250.00');
    expect(DecimalFormatter.formatMoney(Money.fromApi('0.5')), '0.50');
    expect(DecimalFormatter.formatMoney(Money.fromApi('999.99')), '999.99');
    expect(
      DecimalFormatter.formatMoney(Money.fromApi('1234567.10')),
      '1,234,567.10',
    );
    expect(
      DecimalFormatter.formatMoney(Money.fromApi('-1250.00')),
      '-1,250.00',
    );
  });

  test('formatQuantity_TrimsTrailingZeros', () {
    expect(DecimalFormatter.formatQuantity(Quantity.fromApi('24.000')), '24');
    expect(DecimalFormatter.formatQuantity(Quantity.fromApi('1.500')), '1.5');
    expect(DecimalFormatter.formatQuantity(Quantity.fromApi('-2.000')), '-2');
    expect(DecimalFormatter.formatQuantity(Quantity.fromApi('0.125')), '0.125');
  });

  test('formatFactor_TrimsTrailingZeros', () {
    expect(DecimalFormatter.formatFactor(UnitFactor.fromApi('3.000000')), '3');
    expect(
      DecimalFormatter.formatFactor(UnitFactor.fromApi('2.500000')),
      '2.5',
    );
  });

  test('formatConfidencePercent_IntegerPercent', () {
    expect(
      DecimalFormatter.formatConfidencePercent(MatchConfidence.fromApi('0.85')),
      '85',
    );
    expect(
      DecimalFormatter.formatConfidencePercent(MatchConfidence.fromApi('1.00')),
      '100',
    );
    expect(
      DecimalFormatter.formatConfidencePercent(MatchConfidence.fromApi('0.00')),
      '0',
    );
  });
}
