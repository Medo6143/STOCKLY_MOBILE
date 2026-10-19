import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

/// B4: one payment, as the server sees it now.
final class GetPaymentUseCase {
  const new(this._repository);

  final BillingRepository _repository;

  Future<Result<Payment, Failure>> call(String paymentId) =>
      _repository.getPayment(paymentId);
}
