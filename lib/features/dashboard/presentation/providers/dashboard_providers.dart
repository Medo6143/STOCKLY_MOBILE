import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:stockly/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:stockly/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:stockly/features/dashboard/domain/usecases/get_dashboard_summary_use_case.dart';
import 'package:stockly/features/dashboard/domain/usecases/get_expiring_soon_use_case.dart';

// Composition root of the dashboard feature: the only presentation file
// that imports the data layer (design §1.1).

final dashboardRemoteDataSourceProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSource(ref.watch(dioProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) =>
      DashboardRepositoryImpl(ref.watch(dashboardRemoteDataSourceProvider)),
);

final getDashboardSummaryUseCaseProvider = Provider<GetDashboardSummaryUseCase>(
  (ref) => GetDashboardSummaryUseCase(ref.watch(dashboardRepositoryProvider)),
);

final getExpiringSoonUseCaseProvider = Provider<GetExpiringSoonUseCase>(
  (ref) => GetExpiringSoonUseCase(ref.watch(dashboardRepositoryProvider)),
);
