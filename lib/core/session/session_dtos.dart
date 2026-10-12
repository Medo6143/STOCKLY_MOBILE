import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_dtos.freezed.dart';
part 'session_dtos.g.dart';

/// Contract §3 `UserDto`.
///
/// The session DTOs live in core, not in `features/auth/data`, because core
/// classes need them: `TokenStorage` keeps a snapshot of the user and shop,
/// and `TokenRefresher` parses the `AuthResponse` of `POST /api/auth/refresh`.
@freezed
abstract class UserDto with _$UserDto {
  const factory({
    required String id,
    required String email,
    required String fullName,
    required String? phone,
    required String preferredLanguage,
  }) = _UserDto;

  factory fromJson(Map<String, Object?> json) => _$UserDtoFromJson(json);
}

/// Contract §3 `ShopMembershipDto`: the active shop of the token.
@freezed
abstract class ShopMembershipDto with _$ShopMembershipDto {
  const factory({
    required String id,
    required String name,
    required String shopType,
    required String status,
    required String role,
  }) = _ShopMembershipDto;

  factory fromJson(Map<String, Object?> json) =>
      _$ShopMembershipDtoFromJson(json);
}

/// Contract §3 `AuthResponse` (register, login, refresh).
@freezed
abstract class AuthResponseDto with _$AuthResponseDto {
  const factory({
    required String accessToken,
    required DateTime accessTokenExpiresAt,
    required String refreshToken,
    required DateTime refreshTokenExpiresAt,
    required UserDto user,
    required ShopMembershipDto shop,
  }) = _AuthResponseDto;

  factory fromJson(Map<String, Object?> json) =>
      _$AuthResponseDtoFromJson(json);
}

/// Contract A3 request body.
@freezed
abstract class RefreshRequestDto with _$RefreshRequestDto {
  const factory({required String refreshToken}) = _RefreshRequestDto;

  factory fromJson(Map<String, Object?> json) =>
      _$RefreshRequestDtoFromJson(json);
}
