import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_notifier.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/sales/domain/entities/sale_date_range.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';

/// The sales history for one period (S2), page by page. The period's
/// start is fixed when the first page loads.
final class SaleListNotifier extends PagedNotifier<SaleListItem> {
  new(this.range);

  final SaleDateRange range;
  late DateTime _now;

  @override
  Future<PagedState<SaleListItem>> build() {
    _now = ref.read(clockProvider).now();
    return super.build();
  }

  @override
  Future<Result<Paged<SaleListItem>, Failure>> fetchPage(int page) =>
      ref.read(getSalesUseCaseProvider).call(range, now: _now, page: page);
}

final AsyncNotifierProviderFamily<
  SaleListNotifier,
  PagedState<SaleListItem>,
  SaleDateRange
>
saleListProvider = AsyncNotifierProvider.autoDispose
    .family<SaleListNotifier, PagedState<SaleListItem>, SaleDateRange>(
      SaleListNotifier.new,
    );
