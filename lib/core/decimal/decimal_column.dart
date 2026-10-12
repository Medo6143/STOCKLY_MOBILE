import 'package:decimal/decimal.dart';

/// The database columns behind the contract's decimal kinds, with the
/// backend's exclusive limits (`Precision.OutOfRange` above them).
enum DecimalColumn {
  /// `numeric(18,2)`.
  money,

  /// `numeric(14,3)`.
  quantity,

  /// `numeric(14,6)`.
  factor;

  static final Decimal _moneyLimit = Decimal.parse('10000000000000000');
  static final Decimal _quantityLimit = Decimal.parse('100000000000');
  static final Decimal _factorLimit = Decimal.parse('100000000');

  /// `true` when [value] fits this column.
  bool fits(Decimal value) =>
      value.abs() <
      switch (this) {
        DecimalColumn.money => _moneyLimit,
        DecimalColumn.quantity => _quantityLimit,
        DecimalColumn.factor => _factorLimit,
      };
}
