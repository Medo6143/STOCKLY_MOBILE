import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';

part 'product_base_unit.freezed.dart';

/// The base unit shown in the product list.
@freezed
abstract class ProductBaseUnit with _$ProductBaseUnit {
  const factory({
    required String id,
    required String name,
    required Money sellPrice,
  }) = _ProductBaseUnit;
}
