import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

/// B2: the shop's plan, its limits and today's use.
final class GetSubscriptionUseCase {
  const new(this._repository);

  final BillingRepository _repository;

  Future<Result<SubscriptionSummary, Failure>> call() =>
      _repository.getSubscription();
}
