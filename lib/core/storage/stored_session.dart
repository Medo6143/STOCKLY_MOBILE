import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/session/session_dtos.dart';

part 'stored_session.freezed.dart';
part 'stored_session.g.dart';

/// The one JSON blob kept in secure storage (design §4.3): tokens, expiries
/// and a snapshot of the user and shop for offline start.
@freezed
abstract class StoredSession with _$StoredSession {
  const factory({
    required String accessToken,
    required DateTime accessTokenExpiresAt,
    required String refreshToken,
    required DateTime refreshTokenExpiresAt,
    required UserDto user,
    required ShopMembershipDto shop,
  }) = _StoredSession;

  factory fromJson(Map<String, Object?> json) => _$StoredSessionFromJson(json);

  /// The session to store after register, login or refresh.
  factory fromAuthResponse(AuthResponseDto response) => StoredSession(
    accessToken: response.accessToken,
    accessTokenExpiresAt: response.accessTokenExpiresAt,
    refreshToken: response.refreshToken,
    refreshTokenExpiresAt: response.refreshTokenExpiresAt,
    user: response.user,
    shop: response.shop,
  );
}
