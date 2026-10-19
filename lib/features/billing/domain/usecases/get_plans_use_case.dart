import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

/// B1: the plans the shop can choose from.
final class GetPlansUseCase {
  const new(this._repository);

  final BillingRepository _repository;

  Future<Result<List<BillingPlan>, Failure>> call() => _repository.getPlans();
}
