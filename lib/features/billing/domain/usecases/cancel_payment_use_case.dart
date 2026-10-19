import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

/// B6 (Owner): gives up a pending payment so another method can be used.
final class CancelPaymentUseCase {
  const new(this._repository);

  final BillingRepository _repository;

  Future<Result<Payment, Failure>> call(String paymentId) =>
      _repository.cancelPayment(paymentId);
}
