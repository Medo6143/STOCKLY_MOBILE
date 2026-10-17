import 'package:json_annotation/json_annotation.dart';
import 'package:stockly/core/time/calendar_date.dart';

/// JSON converters for contract dates (`yyyy-MM-dd`). A malformed date
/// fails parsing, which becomes `MalformedResponseFailure`.
final class CalendarDateConverter
    implements JsonConverter<CalendarDate, String> {
  const new();

  @override
  CalendarDate fromJson(String json) => CalendarDate.fromApi(json);

  @override
  String toJson(CalendarDate object) => object.toApi();
}

final class NullableCalendarDateConverter
    implements JsonConverter<CalendarDate?, String?> {
  const new();

  @override
  CalendarDate? fromJson(String? json) =>
      json == null ? null : CalendarDate.fromApi(json);

  @override
  String? toJson(CalendarDate? object) => object?.toApi();
}
