import 'package:dio/dio.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/features/dashboard/data/models/dashboard_dtos.dart';

/// Contract D1–D2. Throws `DioException`; the repository maps it.
final class DashboardRemoteDataSource {
  const new(this._dio);

  final Dio _dio;

  /// D1.
  Future<DashboardSummaryDto> getSummary() async {
    final response = await _dio.get<Object?>(ApiPaths.dashboardSummary);
    return DashboardSummaryDto.fromJson(requireJsonObject(response.data));
  }

  /// D2.
  Future<PagedResponseDto<ExpiringItemDto>> getExpiringSoon({
    required int days,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get<Object?>(
      ApiPaths.dashboardExpiringSoon,
      queryParameters: {
        ApiQuery.days: days,
        ApiQuery.page: page,
        ApiQuery.pageSize: pageSize,
      },
    );
    return PagedResponseDto.parse(response.data, ExpiringItemDto.fromJson);
  }
}
