import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';

part 'product_lookup.freezed.dart';

/// A barcode match (contract P12): [unit] is the unit whose barcode
/// matched, or the base unit for a product barcode.
@freezed
abstract class ProductLookup with _$ProductLookup {
  const factory({required ProductListItem product, required ProductUnit unit}) =
      _ProductLookup;
}
