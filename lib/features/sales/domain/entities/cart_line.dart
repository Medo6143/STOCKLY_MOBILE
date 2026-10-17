import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/sales/domain/entities/sale_input_rules.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';

part 'cart_line.freezed.dart';

/// One line of the quick-sale cart (design §11 cart rules). [key] is a
/// local id; [quantityText] and [priceText] are what the cashier typed,
/// with their parsed values or issues. [units] are the product's units
/// known so far ([unitsLoaded] once P2 answered).
@freezed
abstract class CartLine with _$CartLine {
  const factory({
    required int key,
    required String productId,
    required String productName,
    required ProductUnit unit,
    required List<ProductUnit> units,
    required Quantity stock,
    required String baseUnitName,
    required String quantityText,
    required Quantity? quantity,
    @Default(false) bool unitsLoaded,
    SaleFieldIssue? quantityIssue,

    /// Blank: no override, the unit's sell price is charged.
    @Default('') String priceText,
    Money? priceOverride,
    SaleFieldIssue? priceIssue,
  }) = _CartLine;
}

extension CartLineX on CartLine {
  static const int _previewScale = 2;

  /// The price charged: the override, else the unit's sell price.
  Money get price => priceOverride ?? unit.sellPrice;

  bool get isValid => quantity != null && priceIssue == null;

  /// `quantity × price` for the preview, rounded to piasters; the server's
  /// line total wins.
  Money? get totalPreview {
    final value = quantity;
    return value == null
        ? null
        : Money.fromDecimal(price.times(value).round(scale: _previewScale));
  }

  /// The S1 line. Only valid lines are sent.
  SaleRequestItem toRequestItem() => SaleRequestItem(
    productId: productId,
    productUnitId: unit.id,
    quantity: quantity!,
    unitPrice: priceOverride,
  );
}

/// The cart's total preview: the sum of the valid lines.
Money cartTotalPreview(List<CartLine> lines) => lines.fold(
  Money.zero,
  (sum, line) => sum + (line.totalPreview ?? Money.zero),
);
