import 'package:decimal/decimal.dart';

/// One line of a fake sale (contract `SaleItemDto`). [quantity] is in the
/// line's unit; [balanceAfter] is the product's stock in base units after
/// this line.
final class FakeSaleItem {
  const new({
    required this.id,
    required this.productId,
    required this.productUnitId,
    required this.productName,
    required this.unitName,
    required this.quantity,
    required this.listUnitPrice,
    required this.unitPrice,
    required this.lineTotal,
    required this.balanceAfter,
  });

  final String id;
  final String productId;
  final String productUnitId;
  final String productName;
  final String unitName;
  final Decimal quantity;
  final Decimal listUnitPrice;
  final Decimal unitPrice;
  final Decimal lineTotal;
  final Decimal balanceAfter;

  bool get priceOverridden => unitPrice != listUnitPrice;
}

/// A sale of the fake shop (contract `SaleDto`). [negativeProductIds] are
/// the products whose stock went below zero with it.
final class FakeSale {
  const new({
    required this.id,
    required this.shopId,
    required this.clientRequestId,
    required this.note,
    required this.items,
    required this.createdAt,
    required this.createdByUserId,
    required this.negativeProductIds,
  });

  final String id;
  final String shopId;
  final String clientRequestId;
  final String? note;
  final List<FakeSaleItem> items;
  final DateTime createdAt;
  final String createdByUserId;
  final List<String> negativeProductIds;

  Decimal get totalAmount =>
      items.fold(Decimal.zero, (sum, item) => sum + item.lineTotal);

  bool get priceOverridden => items.any((item) => item.priceOverridden);
}
