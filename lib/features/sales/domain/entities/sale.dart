import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';

part 'sale.freezed.dart';

/// Contract sale warning codes. `Stock.NegativeBalance` is a warning, not
/// an error: the sale was recorded and the stock went below zero.
enum SaleWarningCode { negativeBalance }

/// A warning of a recorded sale (contract `SaleDto.warnings`).
@freezed
abstract class SaleWarning with _$SaleWarning {
  const factory({required SaleWarningCode code, required String productId}) =
      _SaleWarning;
}

/// One line of a recorded sale (contract `SaleItemDto`). [listUnitPrice] is
/// the unit's sell price at sale time, [unitPrice] what was charged;
/// [balanceAfter] is the product's stock in base units after this line.
@freezed
abstract class SaleItem with _$SaleItem {
  const factory({
    required String id,
    required String productId,
    required String productName,
    required String productUnitId,
    required String unitName,
    required Quantity quantity,
    required Money listUnitPrice,
    required Money unitPrice,
    required bool priceOverridden,
    required Money lineTotal,
    required Quantity balanceAfter,
  }) = _SaleItem;
}

/// A recorded sale (contract `SaleDto`).
@freezed
abstract class Sale with _$Sale {
  const factory({
    required String id,
    required String clientRequestId,
    required Money totalAmount,
    required String? note,
    required bool priceOverridden,
    required List<SaleItem> items,
    required DateTime createdAt,
    required String createdByUserId,
    required List<SaleWarning> warnings,
  }) = _Sale;
}

extension SaleX on Sale {
  /// The product names of the negative-stock warnings, in warning order.
  List<String> get negativeStockProducts => [
    for (final warning in warnings)
      if (warning.code == SaleWarningCode.negativeBalance)
        items
                .where((item) => item.productId == warning.productId)
                .firstOrNull
                ?.productName ??
            warning.productId,
  ];
}
