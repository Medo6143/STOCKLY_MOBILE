import 'package:stockly/core/decimal/decimal_input_parser.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';

/// Contract S1 limits.
abstract final class SaleRules {
  /// At most this many lines per sale.
  static const int maxLines = 100;

  /// The longest note.
  static const int noteMaxLength = 500;
}

/// Why a typed cart value is not accepted. Number issues mirror the
/// server's `Precision.*` codes (design §5.3).
enum SaleFieldIssue {
  required,
  invalidNumber,
  tooManyDecimals,
  negative,
  notPositive,
  outOfRange,
}

/// A typed number: the value, or why it is not accepted.
typedef SaleParsed<T> = ({T? value, SaleFieldIssue? issue});

/// Device-side checks of the quick-sale cart (design §11 cart rules). The
/// server stays the authority.
abstract final class SaleInputRules {
  /// A line quantity: `> 0`, at most 3 decimals.
  static SaleParsed<Quantity> quantity(String text) {
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

  /// A price override: `>= 0`, at most 2 decimals; blank means no override
  /// (the unit's sell price).
  static SaleParsed<Money> priceOverride(String text) {
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
      DecimalInputEmpty() => (value: null, issue: null),
      _ => (value: null, issue: _issueOf(parsed)),
    };
  }

  static SaleFieldIssue _issueOf(DecimalInputResult result) => switch (result) {
    DecimalInputEmpty() => SaleFieldIssue.required,
    DecimalInputInvalidFormat() ||
    DecimalInputValid() => SaleFieldIssue.invalidNumber,
    DecimalInputTooManyDecimals() => SaleFieldIssue.tooManyDecimals,
    DecimalInputNegativeNotAllowed() => SaleFieldIssue.negative,
    DecimalInputZeroNotAllowed() => SaleFieldIssue.notPositive,
    DecimalInputOutOfRange() => SaleFieldIssue.outOfRange,
  };
}
