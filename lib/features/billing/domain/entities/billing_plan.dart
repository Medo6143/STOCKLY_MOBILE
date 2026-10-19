import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';

part 'billing_plan.freezed.dart';

/// One plan the shop can be on (contract §12.1 `BillingPlan`). [name] is
/// already in the request language.
@freezed
abstract class BillingPlan with _$BillingPlan {
  const factory({
    required String id,
    required String code,
    required String name,
    required Money monthlyPrice,
    required int dailyScanQuota,
    required int maxMembers,
    required bool isFree,
    required bool isCurrent,
  }) = _BillingPlan;
}

extension BillingPlanX on BillingPlan {
  /// Only a paid plan that the shop is not on can be checked out (B3
  /// answers `Billing.FreePlan` for a free one).
  bool get canCheckOut => !isFree && !isCurrent;
}
