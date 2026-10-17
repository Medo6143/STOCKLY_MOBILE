import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';

part 'sale_request.freezed.dart';

/// One line of an S1 request. [unitPrice] is `null` unless the cashier
/// changed the price; the server then uses the unit's sell price.
@freezed
abstract class SaleRequestItem with _$SaleRequestItem {
  const factory({
    required String productId,
    required String productUnitId,
    required Quantity quantity,
    required Money? unitPrice,
  }) = _SaleRequestItem;
}

/// An S1 request. [clientRequestId] is created once per sale and reused on
/// every retry (ADR-0006).
@freezed
abstract class SaleRequest with _$SaleRequest {
  const factory({
    required String clientRequestId,
    required String? note,
    required List<SaleRequestItem> items,
  }) = _SaleRequest;
}
