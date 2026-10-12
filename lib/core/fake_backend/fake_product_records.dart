import 'package:decimal/decimal.dart';

/// Contract `StockMovementDto.reason` values.
abstract final class FakeMovementReasons {
  static const String invoiceReceipt = 'InvoiceReceipt';
  static const String sale = 'Sale';
  static const String manualAdjustment = 'ManualAdjustment';
  static const String stockCount = 'StockCount';

  /// The note of the movement behind an opening quantity (contract P3).
  static const String openingStockNote = 'Opening stock';
}

/// A unit of a fake product. The base unit's factor is always 1.
final class FakeUnit {
  new({
    required this.id,
    required this.name,
    required this.factor,
    required this.sellPrice,
    required this.barcode,
    required this.isBase,
  });

  final String id;
  String name;
  Decimal factor;
  Decimal sellPrice;
  String? barcode;
  final bool isBase;
}

/// A product of the fake shop. [quantity] only changes together with a new
/// [FakeMovement] (AGENTS.md rule 1).
final class FakeProduct {
  new({
    required this.id,
    required this.shopId,
    required this.name,
    required this.barcode,
    required this.category,
    required this.costPrice,
    required this.lowStockThreshold,
    required this.units,
    required this.createdAt,
    this.isArchived = false,
  }) : updatedAt = createdAt;

  final String id;
  final String shopId;
  String name;
  String? barcode;
  String? category;
  Decimal quantity = Decimal.zero;
  Decimal costPrice;
  Decimal lowStockThreshold;
  bool isArchived;
  final List<FakeUnit> units;
  final DateTime createdAt;
  DateTime updatedAt;

  FakeUnit get baseUnit => units.firstWhere((u) => u.isBase);

  bool get isLowStock => quantity <= lowStockThreshold;

  FakeUnit? unitById(String? unitId) {
    for (final unit in units) {
      if (unit.id == unitId) {
        return unit;
      }
    }
    return null;
  }
}

/// One append-only stock movement, in the base unit.
final class FakeMovement {
  new({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.quantityChange,
    required this.balanceAfter,
    required this.reason,
    required this.createdByUserId,
    required this.createdAt,
    this.invoiceId,
    this.saleId,
    this.note,
  });

  final String id;
  final String shopId;
  final String productId;
  final Decimal quantityChange;
  final Decimal balanceAfter;
  final String reason;
  final String? invoiceId;
  final String? saleId;
  final String? note;
  final String createdByUserId;
  final DateTime createdAt;
}
