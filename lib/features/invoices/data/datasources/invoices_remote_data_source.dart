import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/features/invoices/data/models/invoice_dtos.dart';

/// The answer to I1: `202` for a new scan, `200` for a repeat of the same
/// `clientRequestId`.
@immutable
final class ScanUploadResponse {
  const new({required this.isRepeat, required this.invoice});

  final bool isRepeat;
  final InvoiceListItemDto invoice;
}

/// Contract I1–I4. Throws `DioException`; callers map it.
final class InvoicesRemoteDataSource {
  const new(this._dio);

  final Dio _dio;

  static final DioMediaType _jpeg = DioMediaType.parse(ScanLimits.jpegMimeType);

  /// I1: the queued JPEG at [imagePath] with its stored [clientRequestId].
  Future<ScanUploadResponse> scan({
    required String clientRequestId,
    required String imagePath,
  }) async {
    final form = FormData.fromMap({
      ApiForm.image: await MultipartFile.fromFile(
        imagePath,
        filename: '$clientRequestId${ScanLimits.jpegExtension}',
        contentType: _jpeg,
      ),
      ApiForm.clientRequestId: clientRequestId,
    });
    final response = await _dio.post<Object?>(
      ApiPaths.invoicesScan,
      data: form,
    );
    return ScanUploadResponse(
      isRepeat: response.statusCode == HttpStatus.ok,
      invoice: InvoiceListItemDto.fromJson(requireJsonObject(response.data)),
    );
  }

  /// I2.
  Future<PagedResponseDto<InvoiceListItemDto>> getInvoices({
    required String? status,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get<Object?>(
      ApiPaths.invoices,
      queryParameters: {
        ApiQuery.status: ?status,
        ApiQuery.page: page,
        ApiQuery.pageSize: pageSize,
      },
    );
    return PagedResponseDto.parse(response.data, InvoiceListItemDto.fromJson);
  }

  /// I3.
  Future<InvoiceDetailDto> getInvoice(String invoiceId) async {
    final response = await _dio.get<Object?>(ApiPaths.invoice(invoiceId));
    return InvoiceDetailDto.fromJson(requireJsonObject(response.data));
  }

  /// I4.
  Future<InvoiceDetailDto> updateItems(
    String invoiceId,
    UpdateInvoiceItemsRequestDto request,
  ) async {
    final response = await _dio.put<Object?>(
      ApiPaths.invoiceItems(invoiceId),
      data: request.toJson(),
    );
    return InvoiceDetailDto.fromJson(requireJsonObject(response.data));
  }
}
