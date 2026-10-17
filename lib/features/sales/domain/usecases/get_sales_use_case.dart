import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/sales/domain/entities/sale_date_range.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

/// Rows per page of the sales history.
abstract final class SalePaging {
  static const int pageSize = 20;
}

/// S2: one page of the sales in `range`, as seen at `now`.
final class GetSalesUseCase {
  const new(this._repository);

  final SalesRepository _repository;

  Future<Result<Paged<SaleListItem>, Failure>> call(
    SaleDateRange range, {
    required DateTime now,
    required int page,
  }) => _repository.getSales(
    from: range.fromUtc(now),
    page: page,
    pageSize: SalePaging.pageSize,
  );
}
