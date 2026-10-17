import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';

/// Contract D1–D2.
abstract interface class DashboardRepository {
  /// D1.
  Future<Result<DashboardSummary, Failure>> getSummary();

  /// D2, soonest first.
  Future<Result<Paged<ExpiringItem>, Failure>> getExpiringSoon({
    required int days,
    required int page,
    required int pageSize,
  });
}
