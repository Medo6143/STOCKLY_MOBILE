import 'package:flutter/foundation.dart';

/// A calendar day without a time or zone (contract §1.2 `date`,
/// `yyyy-MM-dd`), such as an invoice date or an expiry date.
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  const new(this.year, this.month, this.day);

  /// Parses a contract date. Throws [FormatException] for anything that is
  /// not an existing `yyyy-MM-dd` day.
  factory fromApi(String raw) {
    final match = _pattern.firstMatch(raw);
    if (match == null) {
      throw FormatException('Expected yyyy-MM-dd', raw);
    }
    final date = CalendarDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    final check = date.toDateTime();
    if (check.month != date.month || check.day != date.day) {
      throw FormatException('Not a calendar day', raw);
    }
    return date;
  }

  /// The day of [value] in its own time zone.
  factory fromDateTime(DateTime value) =>
      CalendarDate(value.year, value.month, value.day);

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static const int _yearDigits = 4;
  static const int _partDigits = 2;

  final int year;
  final int month;
  final int day;

  /// `yyyy-MM-dd`.
  String toApi() =>
      '${'$year'.padLeft(_yearDigits, '0')}-'
      '${'$month'.padLeft(_partDigits, '0')}-'
      '${'$day'.padLeft(_partDigits, '0')}';

  /// Midnight of this day in local time (for date pickers and formatting).
  DateTime toDateTime() => DateTime(year, month, day);

  @override
  int compareTo(CalendarDate other) => toApi().compareTo(other.toApi());

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toApi();
}
