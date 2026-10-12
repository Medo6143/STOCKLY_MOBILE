import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/auth/domain/entities/shop_membership.dart';
import 'package:stockly/features/auth/domain/entities/user.dart';

part 'session.freezed.dart';

/// The signed-in user and shop. Holds no token strings: tokens never leave
/// the data layer.
@freezed
abstract class Session with _$Session {
  const factory({
    required User user,
    required ShopMembership shop,
    required DateTime accessTokenExpiresAt,
    required DateTime refreshTokenExpiresAt,
  }) = _Session;
}
