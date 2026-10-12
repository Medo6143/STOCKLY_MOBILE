import 'package:stockly/core/decimal/decimal_column.dart';
import 'package:stockly/core/decimal/decimal_input_parser.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';

/// What the user typed, turned into a request value or field issues.
sealed class ProductInput<T> {
  const new();
}

final class ProductInputValid<T> extends ProductInput<T> {
  const new(this.value);

  final T value;
}

final class ProductInputInvalid<T> extends ProductInput<T> {
  const new(this.issues);

  final Map<ProductField, ProductFieldIssue> issues;
}

/// The request rules of contract P3, P4, P6, P7, P9 and P10, checked on the
/// device so the user sees mistakes before a round trip. Numbers are parsed
/// exactly (Arabic-Indic digits accepted, never rounded, design §5.3). The
/// server checks everything again and stays the authority.
abstract final class ProductInputRules {
  static const int barcodeMax = 64;
  static const int categoryMax = 100;
  static const int noteMax = 500;

  /// P3. [includeOpening] is `false` for Staff: the opening quantity is
  /// never sent then (Owner only, contract P3).
  static ProductInput<ProductDraft> create({
    required String name,
    required String barcode,
    required String category,
    required String baseUnitName,
    required String costPrice,
    required String baseUnitSellPrice,
    required String lowStockThreshold,
    required String openingQuantity,
    required bool includeOpening,
  }) {
    final issues = <ProductField, ProductFieldIssue>{};
    final cleanName = _required(issues, ProductField.name, name);
    final cleanBarcode = _optional(
      issues,
      ProductField.barcode,
      barcode,
      barcodeMax,
    );
    final cleanCategory = _optional(
      issues,
      ProductField.category,
      category,
      categoryMax,
    );
    final cleanUnitName = _required(
      issues,
      ProductField.baseUnitName,
      baseUnitName,
    );
    final cost = _money(issues, ProductField.costPrice, costPrice);
    final sell = _money(
      issues,
      ProductField.baseUnitSellPrice,
      baseUnitSellPrice,
    );
    final threshold = _quantity(
      issues,
      ProductField.lowStockThreshold,
      lowStockThreshold,
      required: false,
    );
    final opening = includeOpening
        ? _quantity(
            issues,
            ProductField.openingQuantity,
            openingQuantity,
            required: false,
          )
        : null;
    if (issues.isNotEmpty ||
        cleanName == null ||
        cleanUnitName == null ||
        cost == null ||
        sell == null) {
      return ProductInputInvalid(issues);
    }
    return ProductInputValid(
      ProductDraft(
        name: cleanName,
        barcode: cleanBarcode,
        category: cleanCategory,
        baseUnitName: cleanUnitName,
        costPrice: cost,
        baseUnitSellPrice: sell,
        lowStockThreshold: threshold,
        openingQuantity: opening,
      ),
    );
  }

  /// P4: every field but barcode and category is required.
  static ProductInput<ProductUpdate> update({
    required String name,
    required String barcode,
    required String category,
    required String costPrice,
    required String lowStockThreshold,
  }) {
    final issues = <ProductField, ProductFieldIssue>{};
    final cleanName = _required(issues, ProductField.name, name);
    final cleanBarcode = _optional(
      issues,
      ProductField.barcode,
      barcode,
      barcodeMax,
    );
    final cleanCategory = _optional(
      issues,
      ProductField.category,
      category,
      categoryMax,
    );
    final cost = _money(issues, ProductField.costPrice, costPrice);
    final threshold = _quantity(
      issues,
      ProductField.lowStockThreshold,
      lowStockThreshold,
      required: true,
    );
    if (issues.isNotEmpty ||
        cleanName == null ||
        cost == null ||
        threshold == null) {
      return ProductInputInvalid(issues);
    }
    return ProductInputValid(
      ProductUpdate(
        name: cleanName,
        barcode: cleanBarcode,
        category: cleanCategory,
        costPrice: cost,
        lowStockThreshold: threshold,
      ),
    );
  }

  /// P6 and P7.
  static ProductInput<UnitDraft> unit({
    required String name,
    required String factor,
    required String sellPrice,
    required String barcode,
  }) {
    final issues = <ProductField, ProductFieldIssue>{};
    final cleanName = _required(issues, ProductField.unitName, name);
    final parsedFactor = _number(
      issues,
      ProductField.unitFactor,
      factor,
      maxScale: UnitFactor.scale,
      sign: DecimalSign.positive,
      column: DecimalColumn.factor,
      required: true,
    );
    final sell = _money(issues, ProductField.unitSellPrice, sellPrice);
    final cleanBarcode = _optional(
      issues,
      ProductField.unitBarcode,
      barcode,
      barcodeMax,
    );
    if (issues.isNotEmpty ||
        cleanName == null ||
        parsedFactor == null ||
        sell == null) {
      return ProductInputInvalid(issues);
    }
    return ProductInputValid(
      UnitDraft(
        name: cleanName,
        factor: UnitFactor.fromDecimal(parsedFactor.value),
        sellPrice: sell,
        barcode: cleanBarcode,
      ),
    );
  }

  /// P9: a signed, non-zero change and a required note.
  static ProductInput<StockAdjustmentDraft> adjustment({
    required String quantityChange,
    required String? unitId,
    required String note,
  }) {
    final issues = <ProductField, ProductFieldIssue>{};
    final parsedChange = _number(
      issues,
      ProductField.quantityChange,
      quantityChange,
      maxScale: Quantity.scale,
      sign: DecimalSign.any,
      column: DecimalColumn.quantity,
      required: true,
    );
    final change = parsedChange == null
        ? null
        : Quantity.fromDecimal(parsedChange.value);
    if (change == Quantity.zero) {
      issues[ProductField.quantityChange] = ProductFieldIssue.zero;
    }
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) {
      issues[ProductField.note] = ProductFieldIssue.required;
    } else if (cleanNote.length > noteMax) {
      issues[ProductField.note] = ProductFieldIssue.tooLong;
    }
    if (issues.isNotEmpty || change == null) {
      return ProductInputInvalid(issues);
    }
    return ProductInputValid(
      StockAdjustmentDraft(
        quantityChange: change,
        unitId: unitId,
        note: cleanNote,
      ),
    );
  }

  /// P10: the counted quantity, `>= 0`.
  static ProductInput<StockCountDraft> count({
    required String countedQuantity,
    required String? unitId,
  }) {
    final issues = <ProductField, ProductFieldIssue>{};
    final counted = _quantity(
      issues,
      ProductField.countedQuantity,
      countedQuantity,
      required: true,
    );
    if (issues.isNotEmpty || counted == null) {
      return ProductInputInvalid(issues);
    }
    return ProductInputValid(
      StockCountDraft(countedQuantity: counted, unitId: unitId),
    );
  }

  static String? _required(
    Map<ProductField, ProductFieldIssue> issues,
    ProductField field,
    String value,
  ) {
    final clean = value.trim();
    if (clean.isEmpty) {
      issues[field] = ProductFieldIssue.required;
      return null;
    }
    return clean;
  }

  static String? _optional(
    Map<ProductField, ProductFieldIssue> issues,
    ProductField field,
    String value,
    int max,
  ) {
    final clean = value.trim();
    if (clean.length > max) {
      issues[field] = ProductFieldIssue.tooLong;
    }
    return clean.isEmpty ? null : clean;
  }

  static Money? _money(
    Map<ProductField, ProductFieldIssue> issues,
    ProductField field,
    String raw,
  ) {
    final value = _number(
      issues,
      field,
      raw,
      maxScale: Money.scale,
      sign: DecimalSign.nonNegative,
      column: DecimalColumn.money,
      required: true,
    );
    return value == null ? null : Money.fromDecimal(value.value);
  }

  static Quantity? _quantity(
    Map<ProductField, ProductFieldIssue> issues,
    ProductField field,
    String raw, {
    required bool required,
  }) {
    final value = _number(
      issues,
      field,
      raw,
      maxScale: Quantity.scale,
      sign: DecimalSign.nonNegative,
      column: DecimalColumn.quantity,
      required: required,
    );
    return value == null ? null : Quantity.fromDecimal(value.value);
  }

  /// The parsed number, or `null` with an issue recorded for [field].
  static DecimalInputValid? _number(
    Map<ProductField, ProductFieldIssue> issues,
    ProductField field,
    String raw, {
    required int maxScale,
    required DecimalSign sign,
    required DecimalColumn column,
    required bool required,
  }) {
    final parsed = DecimalInputParser.parse(
      raw,
      maxScale: maxScale,
      sign: sign,
    );
    final ProductFieldIssue? issue;
    DecimalInputValid? value;
    switch (parsed) {
      case DecimalInputValid(value: final valid):
        value = parsed;
        issue = column.fits(valid) ? null : ProductFieldIssue.outOfRange;
      case DecimalInputEmpty():
        issue = required ? ProductFieldIssue.required : null;
      case DecimalInputInvalidFormat():
        issue = ProductFieldIssue.invalidNumber;
      case DecimalInputTooManyDecimals():
        issue = ProductFieldIssue.tooManyDecimals;
      case DecimalInputNegativeNotAllowed():
        issue = ProductFieldIssue.negative;
      case DecimalInputZeroNotAllowed():
        issue = ProductFieldIssue.notPositive;
      case DecimalInputOutOfRange():
        issue = ProductFieldIssue.outOfRange;
    }
    if (issue != null) {
      issues[field] = issue;
      return null;
    }
    return value;
  }
}
