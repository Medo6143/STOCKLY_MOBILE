import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/billing/presentation/providers/payment_history_notifier.dart';
import 'package:stockly/features/billing/presentation/providers/plans_notifier.dart';
import 'package:stockly/features/billing/presentation/providers/subscription_notifier.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';

/// After a payment started, finished or was cancelled: the plan, the
/// plans, the history and the dashboard ask the server again
/// (plans-payments brief).
void invalidateBilling(Ref ref) => ref
  ..invalidate(subscriptionProvider)
  ..invalidate(plansProvider)
  ..invalidate(paymentHistoryProvider)
  ..invalidate(dashboardSummaryProvider);
