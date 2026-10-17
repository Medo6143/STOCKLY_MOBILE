import 'package:stockly/features/dashboard/data/models/dashboard_dtos.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';

extension DashboardSummaryDtoMapper on DashboardSummaryDto {
  DashboardSummary toEntity() => DashboardSummary(
    productCount: productCount,
    lowStockCount: lowStockCount,
    negativeStockCount: negativeStockCount,
    expiringSoonCount: expiringSoonCount,
    todaySales: TodaySales(
      count: todaySales.count,
      total: todaySales.total,
      overriddenSalesCount: todaySales.overriddenSalesCount,
    ),
    invoicesAwaitingReview: invoicesAwaitingReview,
    generatedAt: generatedAt,
  );
}

extension ExpiringItemDtoMapper on ExpiringItemDto {
  ExpiringItem toEntity() => ExpiringItem(
    productId: productId,
    productName: productName,
    expiryDate: expiryDate,
    batchNo: batchNo,
    invoiceId: invoiceId,
    lineQuantity: lineQuantity,
    currentQuantity: currentQuantity,
  );
}
