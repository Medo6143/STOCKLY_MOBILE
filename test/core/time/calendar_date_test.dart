import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/calendar_date_converters.dart';
import 'package:stockly/core/time/date_formatter.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('FromApi_RoundTrips', () {
    final date = CalendarDate.fromApi('2027-03-31');

    expect(date, const CalendarDate(2027, 3, 31));
    expect(date.toApi(), '2027-03-31');
    expect(const CalendarDate(2026, 1, 5).toApi(), '2026-01-05');
  });

  test('FromApi_RejectsMalformedOrMissingDays', () {
    for (final raw in ['2027-3-31', '2027-02-30', '31/03/2027', '']) {
      expect(() => CalendarDate.fromApi(raw), throwsFormatException);
    }
  });

  test('Converters_HandleNull', () {
    const nullable = NullableCalendarDateConverter();
    expect(nullable.fromJson(null), isNull);
    expect(nullable.toJson(null), isNull);
    expect(
      const CalendarDateConverter().fromJson('2026-10-10'),
      const CalendarDate(2026, 10, 10),
    );
  });

  test('Compare_AndFormat_WesternDigitsInArabic', () {
    expect(
      const CalendarDate(
        2026,
        10,
        10,
      ).compareTo(const CalendarDate(2026, 10, 11)),
      isNegative,
    );
    final arabic = DateFormatter.date(const CalendarDate(2026, 10, 10), 'ar');
    expect(arabic, contains('2026'));
    expect(arabic, isNot(contains('٢')));
  });
}
