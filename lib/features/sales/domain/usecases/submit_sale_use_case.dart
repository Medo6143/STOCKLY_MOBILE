import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';
import 'package:stockly/features/sales/domain/repositories/sales_repository.dart';

/// S1: records the sale. Negative stock never blocks it; it comes back as
/// a warning (contract S1).
final class SubmitSaleUseCase {
  const new(this._repository);

  final SalesRepository _repository;

  Future<Result<SaleSubmission, Failure>> call(
    SaleRequest request, {
    required String shopId,
    required String userId,
  }) => _repository.submit(request, shopId: shopId, userId: userId);
}
