import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/session/session_dtos.dart';

part 'me_response_dto.freezed.dart';
part 'me_response_dto.g.dart';

/// Contract A5 response body.
@freezed
abstract class MeResponseDto with _$MeResponseDto {
  const factory({required UserDto user, required ShopMembershipDto shop}) =
      _MeResponseDto;

  factory fromJson(Map<String, Object?> json) => _$MeResponseDtoFromJson(json);
}
