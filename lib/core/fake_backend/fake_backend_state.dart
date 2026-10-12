import 'package:decimal/decimal.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';

/// Contract `ShopRole` values.
abstract final class FakeRoles {
  static const String owner = 'Owner';
  static const String staff = 'Staff';
}

/// Contract `ShopStatus` values.
abstract final class FakeShopStatuses {
  static const String active = 'Active';
  static const String suspended = 'Suspended';
}

/// Contract `shopType` values.
abstract final class FakeShopTypes {
  static const Set<String> all = {'Pharmacy', 'Grocery', 'MobileShop', 'Other'};
}

final class FakeUser {
  new({
    required this.id,
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
    required this.preferredLanguage,
  });

  final String id;
  final String email;

  /// Plain text: fake data only, never logged.
  final String password;
  final String fullName;
  final String? phone;
  final String preferredLanguage;

  /// Failed logins in a row (contract v1.4 lockout).
  int failedLogins = 0;

  /// The end of the current lockout, if any.
  DateTime? lockedUntil;
}

final class FakeShop {
  new({
    required this.id,
    required this.name,
    required this.shopType,
    required this.status,
  });

  final String id;
  final String name;
  final String shopType;
  String status;
}

final class FakeMembership {
  new({
    required this.userId,
    required this.shopId,
    required this.role,
    required this.joinedAt,
    this.active = true,
  });

  final String userId;
  final String shopId;
  final String role;
  final DateTime joinedAt;
  bool active;
}

/// One login's chain of rotated refresh tokens shares a [familyId].
final class FakeRefreshToken {
  new({
    required this.token,
    required this.familyId,
    required this.userId,
    required this.shopId,
    required this.expiresAt,
  });

  final String token;
  final String familyId;
  final String userId;
  final String shopId;
  final DateTime expiresAt;
  bool revoked = false;
}

/// Access tokens stay valid until they expire, like a real JWT.
final class FakeAccessToken {
  new({
    required this.token,
    required this.userId,
    required this.shopId,
    required this.expiresAt,
  });

  final String token;
  final String userId;
  final String shopId;

  /// Not final: the debug panel can expire a token early.
  DateTime expiresAt;
}

/// The fake server's data. The tenant of a request is always taken from its
/// access token, never from the request.
final class FakeBackendState {
  final List<FakeUser> users = [];
  final List<FakeShop> shops = [];
  final List<FakeMembership> memberships = [];
  final Map<String, FakeRefreshToken> refreshTokens = {};
  final Map<String, FakeAccessToken> accessTokens = {};
  final List<FakeProduct> products = [];

  /// Append-only, oldest first.
  final List<FakeMovement> movements = [];

  /// Units referenced by invoice or sale lines (`ProductUnit.InUse`).
  final Set<String> unitsInUse = {};

  /// The product [productId] of [shopId] (another shop's is not found).
  FakeProduct? productOf(String shopId, String? productId) {
    for (final product in products) {
      if (product.id == productId && product.shopId == shopId) {
        return product;
      }
    }
    return null;
  }

  /// Appends a movement and changes the quantity with it, so every
  /// quantity has a movement behind it (AGENTS.md rules 1 and 2).
  FakeMovement recordMovement(
    FakeProduct product, {
    required String id,
    required Decimal change,
    required String reason,
    required String userId,
    required DateTime at,
    String? note,
    String? invoiceId,
    String? saleId,
  }) {
    product
      ..quantity = product.quantity + change
      ..updatedAt = at;
    final movement = FakeMovement(
      id: id,
      shopId: product.shopId,
      productId: product.id,
      quantityChange: change,
      balanceAfter: product.quantity,
      reason: reason,
      createdByUserId: userId,
      createdAt: at,
      invoiceId: invoiceId,
      saleId: saleId,
      note: note,
    );
    movements.add(movement);
    return movement;
  }

  FakeUser? userByEmail(String email) {
    final wanted = email.toLowerCase();
    for (final user in users) {
      if (user.email.toLowerCase() == wanted) {
        return user;
      }
    }
    return null;
  }

  FakeUser? userById(String id) {
    for (final user in users) {
      if (user.id == id) {
        return user;
      }
    }
    return null;
  }

  FakeShop? shopById(String id) {
    for (final shop in shops) {
      if (shop.id == id) {
        return shop;
      }
    }
    return null;
  }

  /// The active membership joined first (contract A2).
  FakeMembership? activeMembershipOf(String userId) {
    final active =
        memberships.where((m) => m.userId == userId && m.active).toList()
          ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
    return active.isEmpty ? null : active.first;
  }

  FakeMembership? membership(String userId, String shopId) {
    for (final m in memberships) {
      if (m.userId == userId && m.shopId == shopId) {
        return m;
      }
    }
    return null;
  }

  /// Ends every access token now, so the next call refreshes (debug panel).
  void expireAccessTokens(DateTime now) {
    for (final token in accessTokens.values) {
      if (token.expiresAt.isAfter(now)) {
        token.expiresAt = now;
      }
    }
  }

  /// Suspends or reactivates [shopId] (debug panel).
  void setShopStatus(String shopId, {required bool suspended}) {
    shopById(shopId)?.status = suspended
        ? FakeShopStatuses.suspended
        : FakeShopStatuses.active;
  }

  /// Revokes every refresh token of [familyId] (reuse or logout).
  void revokeFamily(String familyId) {
    for (final token in refreshTokens.values) {
      if (token.familyId == familyId) {
        token.revoked = true;
      }
    }
  }
}
