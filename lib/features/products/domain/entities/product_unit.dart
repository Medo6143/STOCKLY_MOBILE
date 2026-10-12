import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/unit_factor.dart';

part 'product_unit.freezed.dart';

/// A unit of a product (contract `UnitDto`): [factor] base units in one of
/// this unit; the base unit's factor is always 1.
@freezed
abstract class ProductUnit with _$ProductUnit {
  const factory({
    required String id,
    required String name,
    required UnitFactor factor,
    required Money sellPrice,
    required String? barcode,
    required bool isBase,
  }) = _ProductUnit;
}
