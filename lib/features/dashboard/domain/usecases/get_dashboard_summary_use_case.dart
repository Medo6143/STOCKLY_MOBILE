import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/domain/repositories/dashboard_repository.dart';

/// D1: the dashboard counts and today's sales.
final class GetDashboardSummaryUseCase {
  const new(this._repository);

  final DashboardRepository _repository;

  Future<Result<DashboardSummary, Failure>> call() => _repository.getSummary();
}
