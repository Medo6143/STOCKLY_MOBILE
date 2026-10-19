import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/seed/fake_billing_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_invoice_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_product_seed.dart';

/// Demo accounts of the fake backend (fake data, documented in README).
abstract final class FakeSeed {
  static const String ownerEmail = 'mona@stockly.test';
  static const String staffEmail = 'karim@stockly.test';
  static const String password = 'Stockly123';

  static const String _shopId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d01';
  static const String _ownerId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d02';
  static const String _staffId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d03';

  /// A pharmacy with an Owner, a Staff member, the product catalogue of
  /// [FakeProductSeed], the invoices of [FakeInvoiceSeed] and the plans of
  /// [FakeBillingSeed] (on the free one); the `Processing` invoice is read
  /// after [processingDelay].
  static FakeBackendState pharmacy(
    DateTime now, {
    Duration processingDelay = FakeBackendConfig.defaultProcessingDelay,
  }) {
    final state = FakeBackendState();
    state.shops.add(
      FakeShop(
        id: _shopId,
        name: 'صيدلية الشفاء',
        shopType: 'Pharmacy',
        status: FakeShopStatuses.active,
      ),
    );
    state.users
      ..add(
        FakeUser(
          id: _ownerId,
          email: ownerEmail,
          password: password,
          fullName: 'منى عادل',
          phone: '01001234567',
          preferredLanguage: 'ar',
        ),
      )
      ..add(
        FakeUser(
          id: _staffId,
          email: staffEmail,
          password: password,
          fullName: 'كريم سمير',
          phone: null,
          preferredLanguage: 'ar',
        ),
      );
    state.memberships
      ..add(
        FakeMembership(
          userId: _ownerId,
          shopId: _shopId,
          role: FakeRoles.owner,
          joinedAt: now,
        ),
      )
      ..add(
        FakeMembership(
          userId: _staffId,
          shopId: _shopId,
          role: FakeRoles.staff,
          joinedAt: now,
        ),
      );
    FakeProductSeed.addTo(state, shopId: _shopId, userId: _ownerId, now: now);
    FakeInvoiceSeed.addTo(
      state,
      shopId: _shopId,
      now: now,
      processingDelay: processingDelay,
    );
    FakeBillingSeed.addTo(state, shopId: _shopId, now: now);
    return state;
  }
}
