import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';

/// The dashboard (D1). An invoice confirm or a sale invalidates it
/// (design §2.3).
final class DashboardSummaryNotifier extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() => ref
      .watch(getDashboardSummaryUseCaseProvider)
      .call()
      .then((result) => result.toFuture());
}

final AsyncNotifierProvider<DashboardSummaryNotifier, DashboardSummary>
dashboardSummaryProvider =
    AsyncNotifierProvider.autoDispose<
      DashboardSummaryNotifier,
      DashboardSummary
    >(DashboardSummaryNotifier.new);
