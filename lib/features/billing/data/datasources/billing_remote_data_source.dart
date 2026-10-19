import 'package:dio/dio.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/features/billing/data/models/billing_dtos.dart';

/// Contract B1–B6. Throws `DioException`; the repository maps it.
final class BillingRemoteDataSource {
  const new(this._dio);

  final Dio _dio;

  /// B1: a JSON array, not paged.
  Future<List<BillingPlanDto>> getPlans() async {
    final response = await _dio.get<Object?>(ApiPaths.billingPlans);
    final data = response.data;
    if (data is! List<Object?>) {
      throw const FormatException('Expected a JSON array');
    }
    return [
      for (final item in data) BillingPlanDto.fromJson(requireJsonObject(item)),
    ];
  }

  /// B2.
  Future<SubscriptionSummaryDto> getSubscription() async {
    final response = await _dio.get<Object?>(ApiPaths.billingSubscription);
    return SubscriptionSummaryDto.fromJson(requireJsonObject(response.data));
  }

  /// B3: `201` for a new payment, `200` for a repeat of the same
  /// `clientRequestId`; both carry the payment.
  Future<PaymentDto> checkout(CheckoutRequestDto request) async {
    final response = await _dio.post<Object?>(
      ApiPaths.billingCheckout,
      data: request.toJson(),
    );
    return PaymentDto.fromJson(requireJsonObject(response.data));
  }

  /// B4.
  Future<PaymentDto> getPayment(String paymentId) async {
    final response = await _dio.get<Object?>(
      ApiPaths.billingPayment(paymentId),
    );
    return PaymentDto.fromJson(requireJsonObject(response.data));
  }

  /// B5.
  Future<PagedResponseDto<PaymentDto>> getPayments({
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get<Object?>(
      ApiPaths.billingPayments,
      queryParameters: {ApiQuery.page: page, ApiQuery.pageSize: pageSize},
    );
    return PagedResponseDto.parse(response.data, PaymentDto.fromJson);
  }

  /// B6.
  Future<PaymentDto> cancelPayment(String paymentId) async {
    final response = await _dio.post<Object?>(
      ApiPaths.billingPaymentCancel(paymentId),
    );
    return PaymentDto.fromJson(requireJsonObject(response.data));
  }
}
