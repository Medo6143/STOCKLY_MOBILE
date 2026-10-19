import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/billing/domain/entities/billing_timings.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

/// B5: one page of the payment history, newest first.
final class GetPaymentsUseCase {
  const new(this._repository);

  final BillingRepository _repository;

  Future<Result<Paged<Payment>, Failure>> call({required int page}) =>
      _repository.getPayments(page: page, pageSize: PaymentPaging.pageSize);
}
