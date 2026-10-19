import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/wallet_phone_rules.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

/// B3: starts a payment for a plan. The wallet phone is sent normalized
/// and only for [PaymentMethod.wallet]; the caller keeps the
/// `clientRequestId` of an attempt for its retries (rule 20).
final class CheckoutUseCase {
  const new(this._repository);

  final BillingRepository _repository;

  Future<Result<Payment, Failure>> call(CheckoutRequest request) =>
      _repository.checkout(
        request.copyWith(
          walletPhone: request.method == PaymentMethod.wallet
              ? WalletPhoneRules.normalize(request.walletPhone ?? '')
              : null,
        ),
      );
}
