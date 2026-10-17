import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/decimal_input_parser.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/new_product.dart';

part 'invoice_input_rules.freezed.dart';

/// Why a typed review value is not accepted. Number issues mirror the
/// server's `Precision.*` codes (design §5.3).
enum InvoiceFieldIssue {
  required,
  invalidNumber,
  tooManyDecimals,
  negative,
  notPositive,
  outOfRange,
}

/// The fields of the line editor.
enum InvoiceLineField {
  rawName,
  product,
  unit,
  quantity,
  unitPrice,
  newProductName,
  newProductBaseUnitName,
  newProductSellPrice,
}

/// The product part of the line editor, as typed.
@freezed
sealed class LineChoiceInput with _$LineChoiceInput {
  /// A product from the catalogue; [unitId] is `null` until a unit is
  /// picked.
  const factory existing({
    required String productId,
    required String productName,
    String? unitId,
    String? unitName,
  }) = ExistingChoiceInput;

  /// A product created on confirm.
  const factory newProduct({
    required String name,
    required String baseUnitName,
    required String sellPrice,
  }) = NewProductChoiceInput;

  /// Nothing picked yet.
  const factory none() = NoChoiceInput;
}

/// What the line editor collects.
@freezed
abstract class InvoiceLineInput with _$InvoiceLineInput {
  const factory({
    required int lineNo,
    required String rawName,
    required LineChoiceInput choice,
    required String quantity,
    required String unitPrice,
    required String batchNo,
    CalendarDate? expiryDate,
  }) = _InvoiceLineInput;
}

/// A checked line, or the issue of each field.
@freezed
sealed class InvoiceLineCheck with _$InvoiceLineCheck {
  const factory valid(InvoiceLineDraft line) = InvoiceLineValid;

  const factory invalid(Map<InvoiceLineField, InvoiceFieldIssue> issues) =
      InvoiceLineInvalid;
}

/// A typed number: the value, or why it is not accepted.
typedef ParsedField<T> = ({T? value, InvoiceFieldIssue? issue});

/// Device-side checks of the review screens. The server stays the
/// authority; these only catch what the user can fix before saving.
abstract final class InvoiceInputRules {
  /// An optional money field (`>= 0`, 2 decimals); blank is `null`.
  static ParsedField<Money> optionalMoney(String text) =>
      _money(text, required: false);

  /// Checks one line of the editor. [previous] keeps the server's line
  /// total and confidence while nothing that changes them was edited.
  static InvoiceLineCheck line(
    InvoiceLineInput input, {
    InvoiceLineDraft? previous,
  }) {
    final issues = <InvoiceLineField, InvoiceFieldIssue>{};
    final rawName = input.rawName.trim();
    if (rawName.isEmpty) {
      issues[InvoiceLineField.rawName] = InvoiceFieldIssue.required;
    }
    final quantity = _quantity(input.quantity);
    if (quantity.issue case final issue?) {
      issues[InvoiceLineField.quantity] = issue;
    }
    final price = _money(input.unitPrice, required: true);
    if (price.issue case final issue?) {
      issues[InvoiceLineField.unitPrice] = issue;
    }
    final choice = _choice(input.choice, issues);
    final quantityValue = quantity.value;
    final priceValue = price.value;
    if (issues.isNotEmpty ||
        choice == null ||
        quantityValue == null ||
        priceValue == null) {
      return InvoiceLineCheck.invalid(issues);
    }
    final batch = input.batchNo.trim();
    final sameChoice = previous != null && previous.choice == choice;
    final sameTotal =
        sameChoice &&
        previous.quantity == quantityValue &&
        previous.unitPrice == priceValue;
    return InvoiceLineCheck.valid(
      InvoiceLineDraft(
        lineNo: input.lineNo,
        rawName: rawName,
        choice: choice,
        quantity: quantityValue,
        unitPrice: priceValue,
        expiryDate: input.expiryDate,
        batchNo: batch.isEmpty ? null : batch,
        lineTotal: sameTotal ? previous.lineTotal : null,
        matchConfidence: sameChoice ? previous.matchConfidence : null,
      ),
    );
  }

  static LineProductChoice? _choice(
    LineChoiceInput input,
    Map<InvoiceLineField, InvoiceFieldIssue> issues,
  ) {
    switch (input) {
      case NoChoiceInput():
        issues[InvoiceLineField.product] = InvoiceFieldIssue.required;
        return null;
      case ExistingChoiceInput(
        :final productId,
        :final productName,
        :final unitId,
        :final unitName,
      ):
        if (unitId == null || unitName == null) {
          issues[InvoiceLineField.unit] = InvoiceFieldIssue.required;
          return null;
        }
        return LineProductChoice.existing(
          productId: productId,
          productUnitId: unitId,
          productName: productName,
          unitName: unitName,
        );
      case NewProductChoiceInput(
        :final name,
        :final baseUnitName,
        :final sellPrice,
      ):
        final cleanName = name.trim();
        final cleanUnit = baseUnitName.trim();
        if (cleanName.isEmpty) {
          issues[InvoiceLineField.newProductName] = InvoiceFieldIssue.required;
        }
        if (cleanUnit.isEmpty) {
          issues[InvoiceLineField.newProductBaseUnitName] =
              InvoiceFieldIssue.required;
        }
        final price = _money(sellPrice, required: true);
        if (price.issue case final issue?) {
          issues[InvoiceLineField.newProductSellPrice] = issue;
        }
        final value = price.value;
        if (cleanName.isEmpty || cleanUnit.isEmpty || value == null) {
          return null;
        }
        return LineProductChoice.newProduct(
          NewProduct(
            name: cleanName,
            baseUnitName: cleanUnit,
            sellPrice: value,
          ),
        );
    }
  }

  static ParsedField<Money> _money(String text, {required bool required}) {
    final parsed = DecimalInputParser.parse(
      text,
      maxScale: Money.scale,
      sign: DecimalSign.nonNegative,
    );
    return switch (parsed) {
      DecimalInputValid(:final value) => (
        value: Money.fromDecimal(value),
        issue: null,
      ),
      DecimalInputEmpty() => (
        value: null,
        issue: required ? InvoiceFieldIssue.required : null,
      ),
      _ => (value: null, issue: _issueOf(parsed)),
    };
  }

  static ParsedField<Quantity> _quantity(String text) {
    final parsed = DecimalInputParser.parse(
      text,
      maxScale: Quantity.scale,
      sign: DecimalSign.positive,
    );
    return switch (parsed) {
      DecimalInputValid(:final value) => (
        value: Quantity.fromDecimal(value),
        issue: null,
      ),
      _ => (value: null, issue: _issueOf(parsed)),
    };
  }

  static InvoiceFieldIssue _issueOf(DecimalInputResult result) =>
      switch (result) {
        DecimalInputEmpty() => InvoiceFieldIssue.required,
        DecimalInputInvalidFormat() ||
        DecimalInputValid() => InvoiceFieldIssue.invalidNumber,
        DecimalInputTooManyDecimals() => InvoiceFieldIssue.tooManyDecimals,
        DecimalInputNegativeNotAllowed() => InvoiceFieldIssue.negative,
        DecimalInputZeroNotAllowed() => InvoiceFieldIssue.notPositive,
        DecimalInputOutOfRange() => InvoiceFieldIssue.outOfRange,
      };
}
