import 'package:freezed_annotation/freezed_annotation.dart';

part 'register_request_dto.freezed.dart';
part 'register_request_dto.g.dart';

/// Contract A1 request body.
@freezed
abstract class RegisterRequestDto with _$RegisterRequestDto {
  const factory({
    required String fullName,
    required String email,
    required String password,
    required String preferredLanguage,
    required String deviceId,
    required RegisterShopDto shop,
    String? phone,
  }) = _RegisterRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$RegisterRequestDtoFromJson(json);
}

/// Contract A1 `shop` object.
@freezed
abstract class RegisterShopDto with _$RegisterShopDto {
  const factory({
    required String name,
    required String shopType,
    String? phone,
    String? governorate,
    String? address,
  }) = _RegisterShopDto;

  factory fromJson(Map<String, Object?> json) =>
      _$RegisterShopDtoFromJson(json);
}
