import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:stockly/features/dashboard/data/models/dashboard_mapper.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/domain/repositories/dashboard_repository.dart';

final class DashboardRepositoryImpl implements DashboardRepository {
  const new(this._remote);

  final DashboardRemoteDataSource _remote;

  @override
  Future<Result<DashboardSummary, Failure>> getSummary() =>
      safeApiCall(() async => (await _remote.getSummary()).toEntity());

  @override
  Future<Result<Paged<ExpiringItem>, Failure>> getExpiringSoon({
    required int days,
    required int page,
    required int pageSize,
  }) => safeApiCall(() async {
    final response = await _remote.getExpiringSoon(
      days: days,
      page: page,
      pageSize: pageSize,
    );
    return response.toPaged((item) => item.toEntity());
  });
}
