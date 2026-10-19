import 'package:decimal/decimal.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_billing_records.dart';
import 'package:stockly/core/fake_backend/handlers/fake_invoices_handler.dart';

/// The fake platform's plans (fake data): the free default plan and two
/// paid ones. The seeded shop starts on the free plan.
abstract final class FakeBillingSeed {
  static const String freePlanId = '0192f0a0-6c1e-7b3a-9d2e-b111ab000001';
  static const String basicPlanId = '0192f0a0-6c1e-7b3a-9d2e-b111ab000002';
  static const String proPlanId = '0192f0a0-6c1e-7b3a-9d2e-b111ab000003';

  /// The default plan's daily scans (the backend's default plan).
  static const int freeDailyScans = 50;

  static List<FakePlan> plans() => [
    FakePlan(
      id: freePlanId,
      code: 'free',
      nameAr: 'المجانية',
      nameEn: 'Free',
      monthlyPrice: Decimal.zero,
      dailyScanQuota: freeDailyScans,
      maxMembers: 2,
    ),
    FakePlan(
      id: basicPlanId,
      code: 'basic',
      nameAr: 'الأساسية',
      nameEn: 'Basic',
      monthlyPrice: Decimal.parse('150.00'),
      dailyScanQuota: 150,
      maxMembers: 3,
    ),
    FakePlan(
      id: proPlanId,
      code: 'pro',
      nameAr: 'الاحترافية',
      nameEn: 'Pro',
      monthlyPrice: Decimal.parse('300.00'),
      dailyScanQuota: 500,
      maxMembers: 10,
    ),
  ];

  /// Adds the plans (once) and puts [shopId] on the free plan from today.
  static void addTo(
    FakeBackendState state, {
    required String shopId,
    required DateTime now,
  }) {
    if (state.plans.isEmpty) {
      state.plans.addAll(plans());
    }
    state.subscriptions.add(
      FakeSubscription(
        shopId: shopId,
        planId: freePlanId,
        startsOn: FakeCairoTime.dayOf(now),
        endsOn: null,
      ),
    );
  }
}
