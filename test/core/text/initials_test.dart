import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/text/initials.dart';

/// Design-refresh brief: the profile avatar shows Arabic and Latin
/// initials.
void main() {
  test('Latin_FirstLettersOfTwoWords_UpperCased', () {
    expect(initialsOf('mona adel'), 'MA');
    expect(initialsOf('Mona Adel Hassan'), 'MA');
  });

  test('Arabic_FirstLettersJoinedWithANonJoiner', () {
    expect(initialsOf('منى عادل'), 'م‌ع');
  });

  test('OneWord_OneInitial', () {
    expect(initialsOf('Mona'), 'M');
    expect(initialsOf('منى'), 'م');
  });

  test('ExtraSpaces_AreIgnored', () {
    expect(initialsOf('  mona   adel  '), 'MA');
  });

  test('NoLetters_Empty', () {
    expect(initialsOf(''), isEmpty);
    expect(initialsOf('   '), isEmpty);
    expect(initialsOf('123 456'), isEmpty);
  });
}
