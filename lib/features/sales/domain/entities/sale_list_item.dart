import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';

part 'sale_list_item.freezed.dart';

/// One row of the sales history (contract `SaleListItem`).
@freezed
abstract class SaleListItem with _$SaleListItem {
  const factory({
    required String id,
    required Money totalAmount,
    required int itemCount,
    required DateTime createdAt,
  }) = _SaleListItem;
}
