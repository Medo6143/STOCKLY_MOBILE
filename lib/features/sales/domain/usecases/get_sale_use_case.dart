import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

/// S3: one sale with its lines and warnings.
final class GetSaleUseCase {
  const new(this._repository);

  final SalesRepository _repository;

  Future<Result<Sale, Failure>> call(String saleId) =>
      _repository.getSale(saleId);
}
