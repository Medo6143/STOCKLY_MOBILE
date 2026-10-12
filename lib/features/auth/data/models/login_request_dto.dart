import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_request_dto.freezed.dart';
part 'login_request_dto.g.dart';

/// Contract A2 request body.
@freezed
abstract class LoginRequestDto with _$LoginRequestDto {
  const factory({
    required String email,
    required String password,
    required String deviceId,
  }) = _LoginRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$LoginRequestDtoFromJson(json);
}
