import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/billing/data/datasources/billing_remote_data_source.dart';
import 'package:stockly/features/billing/data/models/billing_mapper.dart';
import 'package:stockly/features/billing/domain/entities/billing_plan.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/subscription_summary.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

final class BillingRepositoryImpl implements BillingRepository {
  const new(this._remote);

  final BillingRemoteDataSource _remote;

  @override
  Future<Result<List<BillingPlan>, Failure>> getPlans() => safeApiCall(
    () async => [for (final plan in await _remote.getPlans()) plan.toEntity()],
  );

  @override
  Future<Result<SubscriptionSummary, Failure>> getSubscription() =>
      safeApiCall(() async => (await _remote.getSubscription()).toEntity());

  @override
  Future<Result<Payment, Failure>> checkout(CheckoutRequest request) =>
      safeApiCall(
        () async => (await _remote.checkout(request.toDto())).toEntity(),
      );

  @override
  Future<Result<Payment, Failure>> getPayment(String paymentId) =>
      safeApiCall(() async => (await _remote.getPayment(paymentId)).toEntity());

  @override
  Future<Result<Paged<Payment>, Failure>> getPayments({
    required int page,
    required int pageSize,
  }) => safeApiCall(() async {
    final response = await _remote.getPayments(page: page, pageSize: pageSize);
    return response.toPaged((item) => item.toEntity());
  });

  @override
  Future<Result<Payment, Failure>> cancelPayment(String paymentId) =>
      safeApiCall(
        () async => (await _remote.cancelPayment(paymentId)).toEntity(),
      );
}
