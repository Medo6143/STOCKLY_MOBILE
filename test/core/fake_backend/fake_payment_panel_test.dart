import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/fake_backend/fake_backend_provider.dart';
import 'package:stockly/core/fake_backend/fake_billing_records.dart';
import 'package:stockly/core/fake_backend/panel/fake_payment_panel.dart';
import 'package:stockly/core/fake_backend/seed/fake_billing_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';

import '../../helpers/fake_app.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles.dart';

/// Plans-payments brief: in fake mode QA finishes a payment from the
/// debug panel ("Simulate payment success / failure").
void main() {
  for (final paid in [true, false]) {
    testWidgets('Simulate_${paid ? 'Success' : 'Failure'}', (tester) async {
      final clock = FakeClock();
      final state = FakeSeed.pharmacy(clock.now());
      final adapter = fakeBackend(clock: clock, state: state);
      final payment = FakePayment(
        id: '0192f0a0-6c1e-7b3a-9d2e-ba1e00000001',
        shopId: state.shops.single.id,
        clientRequestId: '0192f0a0-6c1e-7b3a-9d2e-ba1e00000099',
        planId: FakeBillingSeed.basicPlanId,
        amount: Decimal.parse('150.00'),
        method: FakePaymentMethods.card,
        checkoutUrl: null,
        referenceNumber: null,
        expiresAt: clock.now().add(const Duration(hours: 1)),
        createdAt: clock.now(),
      );
      state.payments.add(payment);
      var settled = 0;
      await pumpLocalizedApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => FakePaymentPanel(
                paymentId: payment.id,
                onSettled: () => settled++,
              ),
            ),
            child: const Text('open'),
          ),
        ),
        locale: const Locale('en'),
        overrides: [fakeBackendProvider.overrideWithValue(adapter)],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final l10n = l10nOf(const Locale('en'));
      await tester.tap(
        find.text(
          paid ? l10n.fakePanelPaymentSuccess : l10n.fakePanelPaymentFailure,
        ),
      );
      await tester.pumpAndSettle();

      expect(settled, 1);
      expect(find.byType(FakePaymentPanel), findsNothing);
      expect(
        payment.status,
        paid ? FakePaymentStatuses.paid : FakePaymentStatuses.failed,
      );
    });
  }
}
