import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/domain/repositories/dashboard_repository.dart';

class MockDashboardRepository extends Mock implements DashboardRepository;

const String expiringInvoiceId = '0192f0a0-6c1e-7b3a-9d2e-e00000000002';
const String expiringProductId = '0192f0a0-6c1e-7b3a-9d2e-a00000000004';

DashboardSummary summary({
  int productCount = 31,
  int lowStock = 6,
  int negative = 1,
  int expiring = 2,
  int salesCount = 3,
  String total = '1250.50',
  int overridden = 1,
  int awaitingReview = 2,
}) => DashboardSummary(
  productCount: productCount,
  lowStockCount: lowStock,
  negativeStockCount: negative,
  expiringSoonCount: expiring,
  todaySales: TodaySales(
    count: salesCount,
    total: Money.fromApi(total),
    overriddenSalesCount: overridden,
  ),
  invoicesAwaitingReview: awaitingReview,
  generatedAt: DateTime.utc(2026, 10, 12, 7),
);

ExpiringItem expiringItem({
  String name = 'بروفين 400',
  String? batchNo = 'BR-40',
  CalendarDate expiry = const CalendarDate(2026, 11, 1),
}) => ExpiringItem(
  productId: expiringProductId,
  productName: name,
  expiryDate: expiry,
  batchNo: batchNo,
  invoiceId: expiringInvoiceId,
  lineQuantity: Quantity.fromApi('4.000'),
  currentQuantity: Quantity.fromApi('11.000'),
);

Paged<T> dashboardPage<T>(List<T> items, {int page = 1, int? totalCount}) =>
    Paged(
      items: items,
      page: page,
      pageSize: ExpiringSoonWindow.pageSize,
      totalCount: totalCount ?? items.length,
    );

/// A dashboard for app-level tests that do not exercise it.
MockDashboardRepository quietDashboard() {
  final repository = MockDashboardRepository();
  when(repository.getSummary).thenAnswer((_) async => Ok(summary()));
  return repository;
}
