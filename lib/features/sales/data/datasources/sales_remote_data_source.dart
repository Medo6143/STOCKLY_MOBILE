import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/features/sales/data/models/sale_dtos.dart';

/// The answer to S1: `201` for a new sale, `200` for a repeat of the same
/// `clientRequestId`.
@immutable
final class CreateSaleResponse {
  const new({required this.isRepeat, required this.sale});

  final bool isRepeat;
  final SaleDto sale;
}

/// Contract S1–S3. Throws `DioException`; the repository maps it.
final class SalesRemoteDataSource {
  const new(this._dio);

  final Dio _dio;

  /// S1 with [requestJson], the exact stored body (design §6.8), so a
  /// retry sends the same bytes.
  Future<CreateSaleResponse> createSale(String requestJson) async {
    final response = await _dio.post<Object?>(
      ApiPaths.sales,
      data: requestJson,
      options: Options(contentType: Headers.jsonContentType),
    );
    return CreateSaleResponse(
      isRepeat: response.statusCode == HttpStatus.ok,
      sale: SaleDto.fromJson(requireJsonObject(response.data)),
    );
  }

  /// S2.
  Future<PagedResponseDto<SaleListItemDto>> getSales({
    required DateTime? from,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get<Object?>(
      ApiPaths.sales,
      queryParameters: {
        ApiQuery.from: ?from?.toUtc().toIso8601String(),
        ApiQuery.page: page,
        ApiQuery.pageSize: pageSize,
      },
    );
    return PagedResponseDto.parse(response.data, SaleListItemDto.fromJson);
  }

  /// S3.
  Future<SaleDto> getSale(String saleId) async {
    final response = await _dio.get<Object?>(ApiPaths.sale(saleId));
    return SaleDto.fromJson(requireJsonObject(response.data));
  }
}
