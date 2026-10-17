import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/domain/repositories/dashboard_repository.dart';

/// D2: one page of the lines expiring within `days` days.
final class GetExpiringSoonUseCase {
  const new(this._repository);

  final DashboardRepository _repository;

  Future<Result<Paged<ExpiringItem>, Failure>> call(
    int days, {
    required int page,
  }) => _repository.getExpiringSoon(
    days: days,
    page: page,
    pageSize: ExpiringSoonWindow.pageSize,
  );
}
