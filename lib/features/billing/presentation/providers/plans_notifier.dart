import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';

/// The plans the shop can choose from (B1).
final class PlansNotifier extends AsyncNotifier<List<BillingPlan>> {
  @override
  Future<List<BillingPlan>> build() => ref
      .watch(getPlansUseCaseProvider)
      .call()
      .then((result) => result.toFuture());
}

final AsyncNotifierProvider<PlansNotifier, List<BillingPlan>> plansProvider =
    AsyncNotifierProvider.autoDispose<PlansNotifier, List<BillingPlan>>(
      PlansNotifier.new,
    );
