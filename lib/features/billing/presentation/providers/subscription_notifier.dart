import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';

/// The shop's plan and today's use (B2), shown on the profile and the
/// dashboard. A started, paid or cancelled payment invalidates it.
final class SubscriptionNotifier extends AsyncNotifier<SubscriptionSummary> {
  @override
  Future<SubscriptionSummary> build() => ref
      .watch(getSubscriptionUseCaseProvider)
      .call()
      .then((result) => result.toFuture());
}

final AsyncNotifierProvider<SubscriptionNotifier, SubscriptionSummary>
subscriptionProvider =
    AsyncNotifierProvider.autoDispose<
      SubscriptionNotifier,
      SubscriptionSummary
    >(SubscriptionNotifier.new);
