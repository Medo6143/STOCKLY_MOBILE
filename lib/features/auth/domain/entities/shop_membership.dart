import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/domain/entities/shop_status.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';

part 'shop_membership.freezed.dart';

/// The active shop of the session and the user's role in it.
@freezed
abstract class ShopMembership with _$ShopMembership {
  const factory({
    required String id,
    required String name,
    required ShopType shopType,
    required ShopStatus status,
    required ShopRole role,
  }) = _ShopMembership;
}
