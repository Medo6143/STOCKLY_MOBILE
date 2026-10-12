import 'package:freezed_annotation/freezed_annotation.dart';

part 'problem_details_dto.freezed.dart';
part 'problem_details_dto.g.dart';

/// RFC 7807 error body (contract §1.8). `title` and `detail` are kept for
/// debug only: the UI never shows or switches on them.
@freezed
abstract class ProblemDetailsDto with _$ProblemDetailsDto {
  const factory({
    required int status,
    required String code,
    String? type,
    String? title,
    String? detail,
    String? instance,
    String? traceId,
    String? correlationId,
    Map<String, List<String>>? errors,
  }) = _ProblemDetailsDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ProblemDetailsDtoFromJson(json);
}
