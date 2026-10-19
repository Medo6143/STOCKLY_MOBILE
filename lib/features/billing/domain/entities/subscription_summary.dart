import 'dart:math' as math;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';

part 'subscription_summary.freezed.dart';

/// The shop's plan, its limits and today's use (contract §12.1
/// `SubscriptionSummary`).
@freezed
abstract class SubscriptionSummary with _$SubscriptionSummary {
  const factory({
    required BillingPlan plan,
    required CalendarDate startsOn,

    /// `null` for an open-ended (free) plan.
    required CalendarDate? endsOn,
    required int effectiveDailyScanQuota,
    required int scansToday,
    required int memberCount,

    /// The newest `Pending` payment of the shop, if any.
    required Payment? pendingPayment,
  }) = _SubscriptionSummary;
}

/// When the dashboard suggests an upgrade (plans-payments brief): at 80 %
/// of the daily scan quota, that is `scansToday / quota >= 4 / 5`.
abstract final class QuotaWarning {
  static const int numerator = 4;
  static const int denominator = 5;
}

extension SubscriptionSummaryX on SubscriptionSummary {
  /// Today's scans reached 80 % of the quota (a quota of 0 always has).
  bool get isNearQuota =>
      scansToday * QuotaWarning.denominator >=
      effectiveDailyScanQuota * QuotaWarning.numerator;

  /// The share of today's quota used, `0..1`, for the progress bar.
  double get scanUsage => effectiveDailyScanQuota <= 0
      ? 1
      : math.min(scansToday / effectiveDailyScanQuota, 1);
}
