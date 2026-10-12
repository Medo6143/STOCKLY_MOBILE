import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/core/storage/stored_session.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/shop_membership.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/domain/entities/shop_status.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/auth/domain/entities/user.dart';

/// Contract enum strings (PascalCase) to domain enums and back. An unknown
/// string is a contract violation: [FormatException], which becomes
/// `MalformedResponseFailure`.
abstract final class AuthWire {
  static const Map<ShopType, String> shopTypes = {
    ShopType.pharmacy: 'Pharmacy',
    ShopType.grocery: 'Grocery',
    ShopType.mobileShop: 'MobileShop',
    ShopType.other: 'Other',
  };

  static const Map<ShopStatus, String> shopStatuses = {
    ShopStatus.active: 'Active',
    ShopStatus.suspended: 'Suspended',
  };

  static const Map<ShopRole, String> roles = {
    ShopRole.owner: 'Owner',
    ShopRole.staff: 'Staff',
  };

  static T parse<T>(Map<T, String> wire, String raw) {
    for (final entry in wire.entries) {
      if (entry.value == raw) {
        return entry.key;
      }
    }
    throw FormatException('Unknown enum value', raw);
  }

  static AppLanguage language(String raw) {
    final language = AppLanguage.values.asNameMap()[raw];
    if (language == null) {
      throw FormatException('Unknown language', raw);
    }
    return language;
  }
}

extension UserDtoMapper on UserDto {
  User toEntity() => User(
    id: id,
    email: email,
    fullName: fullName,
    phone: phone,
    preferredLanguage: AuthWire.language(preferredLanguage),
  );
}

extension ShopMembershipDtoMapper on ShopMembershipDto {
  ShopMembership toEntity() => ShopMembership(
    id: id,
    name: name,
    shopType: AuthWire.parse(AuthWire.shopTypes, shopType),
    status: AuthWire.parse(AuthWire.shopStatuses, status),
    role: AuthWire.parse(AuthWire.roles, role),
  );
}

extension StoredSessionMapper on StoredSession {
  Session toEntity() => Session(
    user: user.toEntity(),
    shop: shop.toEntity(),
    accessTokenExpiresAt: accessTokenExpiresAt,
    refreshTokenExpiresAt: refreshTokenExpiresAt,
  );
}
