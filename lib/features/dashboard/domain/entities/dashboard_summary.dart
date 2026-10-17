import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';

part 'dashboard_summary.freezed.dart';

/// Today's sales on the dashboard (contract D1). "Today" is the Cairo
/// calendar day on the server.
@freezed
abstract class TodaySales with _$TodaySales {
  const factory({
    required int count,
    required Money total,
    required int overriddenSalesCount,
  }) = _TodaySales;
}

/// The shop at a glance (contract D1). The server caches it for up to two
/// minutes; [generatedAt] says when it was computed.
@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory({
    required int productCount,
    required int lowStockCount,
    required int negativeStockCount,
    required int expiringSoonCount,
    required TodaySales todaySales,
    required int invoicesAwaitingReview,
    required DateTime generatedAt,
  }) = _DashboardSummary;
}

extension DashboardSummaryX on DashboardSummary {
  /// A new shop: nothing to summarise yet (design §11 empty state).
  bool get isNewShop => productCount == 0;
}
