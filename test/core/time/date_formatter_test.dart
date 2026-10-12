import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stockly/core/time/date_formatter.dart';

/// Design §5.4: dates use the app locale for month names and Western digits
/// in both languages.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  final value = DateTime.utc(2026, 10, 12, 7);

  test('DateTime_ArabicMonthNamesWesternDigits', () {
    final text = DateFormatter.dateTime(value, 'ar');

    expect(text, contains('2026'));
    expect(text, contains('أكتوبر'));
    expect(RegExp('[٠-٩]').hasMatch(text), isFalse);
  });

  test('DateTime_English', () {
    final text = DateFormatter.dateTime(value, 'en');

    expect(text, contains('Oct'));
    expect(text, contains('2026'));
  });
}
