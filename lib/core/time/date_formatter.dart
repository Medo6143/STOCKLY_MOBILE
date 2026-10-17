import 'package:intl/intl.dart';
import 'package:stockly/core/time/calendar_date.dart';

/// Dates and times in the app locale with Western digits in both languages
/// (design §5.4). API timestamps are UTC and shown in device local time.
abstract final class DateFormatter {
  /// `Oct 12, 2026 07:00` / `12 أكتوبر 2026 07:00`.
  static String dateTime(DateTime value, String languageCode) {
    final format = DateFormat.yMMMd(languageCode).add_Hm()
      ..useNativeDigits = false;
    return format.format(value.toLocal());
  }

  /// `Oct 10, 2026` / `10 أكتوبر 2026`: a calendar day, no time zone.
  static String date(CalendarDate value, String languageCode) {
    final format = DateFormat.yMMMd(languageCode)..useNativeDigits = false;
    return format.format(value.toDateTime());
  }

  /// `07:00`: the local time of an API timestamp.
  static String time(DateTime value, String languageCode) {
    final format = DateFormat.Hm(languageCode)..useNativeDigits = false;
    return format.format(value.toLocal());
  }
}
