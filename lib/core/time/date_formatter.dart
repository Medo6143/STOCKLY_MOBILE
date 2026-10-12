import 'package:intl/intl.dart';

/// Dates and times in the app locale with Western digits in both languages
/// (design §5.4). API timestamps are UTC and shown in device local time.
abstract final class DateFormatter {
  /// `Oct 12, 2026 07:00` / `12 أكتوبر 2026 07:00`.
  static String dateTime(DateTime value, String languageCode) {
    final format = DateFormat.yMMMd(languageCode).add_Hm()
      ..useNativeDigits = false;
    return format.format(value.toLocal());
  }
}
