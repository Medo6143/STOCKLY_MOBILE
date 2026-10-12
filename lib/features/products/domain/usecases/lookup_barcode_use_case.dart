import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_lookup.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

/// P12: the product and unit with a barcode (sent trimmed).
final class LookupBarcodeUseCase {
  const new(this._repository);

  final ProductsRepository _repository;

  Future<Result<ProductLookup, Failure>> call(String barcode) =>
      _repository.lookupBarcode(barcode.trim());
}
