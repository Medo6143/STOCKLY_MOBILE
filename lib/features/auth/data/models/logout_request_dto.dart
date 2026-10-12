import 'package:freezed_annotation/freezed_annotation.dart';

part 'logout_request_dto.freezed.dart';
part 'logout_request_dto.g.dart';

/// Contract A4 request body.
@freezed
abstract class LogoutRequestDto with _$LogoutRequestDto {
  const factory({required String refreshToken}) = _LogoutRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$LogoutRequestDtoFromJson(json);
}
