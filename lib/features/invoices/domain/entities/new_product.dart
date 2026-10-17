import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';

part 'new_product.freezed.dart';

/// A product the confirmation will create (contract I4 `newProduct`). Its
/// cost price is the line's unit price; the line quantity is in its base
/// unit.
@freezed
abstract class NewProduct with _$NewProduct {
  const factory({
    required String name,
    required String baseUnitName,
    required Money sellPrice,
  }) = _NewProduct;
}
