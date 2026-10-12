import 'package:dio/dio.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/features/products/data/models/product_dtos.dart';
import 'package:stockly/features/products/data/models/product_request_dtos.dart';

/// Contract P1–P12. Throws `DioException`; the repository maps it.
final class ProductsRemoteDataSource {
  const new(this._dio);

  final Dio _dio;

  /// P1.
  Future<PagedResponseDto<ProductListItemDto>> getProducts({
    required String? search,
    required bool lowStock,
    required bool includeArchived,
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get<Object?>(
      ApiPaths.products,
      queryParameters: {
        ApiQuery.search: ?search,
        if (lowStock) ApiQuery.lowStock: true,
        if (includeArchived) ApiQuery.includeArchived: true,
        ApiQuery.page: page,
        ApiQuery.pageSize: pageSize,
      },
    );
    return PagedResponseDto.parse(response.data, ProductListItemDto.fromJson);
  }

  /// P2.
  Future<ProductDetailDto> getProduct(String productId) async {
    final response = await _dio.get<Object?>(ApiPaths.product(productId));
    return ProductDetailDto.fromJson(requireJsonObject(response.data));
  }

  /// P3.
  Future<ProductDetailDto> createProduct(
    CreateProductRequestDto request,
  ) async {
    final response = await _dio.post<Object?>(
      ApiPaths.products,
      data: request.toJson(),
    );
    return ProductDetailDto.fromJson(requireJsonObject(response.data));
  }

  /// P4.
  Future<ProductDetailDto> updateProduct(
    String productId,
    UpdateProductRequestDto request,
  ) async {
    final response = await _dio.put<Object?>(
      ApiPaths.product(productId),
      data: request.toJson(),
    );
    return ProductDetailDto.fromJson(requireJsonObject(response.data));
  }

  /// P5.
  Future<void> archiveProduct(String productId) =>
      _dio.post<Object?>(ApiPaths.productArchive(productId));

  /// P6.
  Future<UnitDto> addUnit(String productId, UnitRequestDto request) async {
    final response = await _dio.post<Object?>(
      ApiPaths.productUnits(productId),
      data: request.toJson(),
    );
    return UnitDto.fromJson(requireJsonObject(response.data));
  }

  /// P7.
  Future<UnitDto> updateUnit(
    String productId,
    String unitId,
    UnitRequestDto request,
  ) async {
    final response = await _dio.put<Object?>(
      ApiPaths.productUnit(productId, unitId),
      data: request.toJson(),
    );
    return UnitDto.fromJson(requireJsonObject(response.data));
  }

  /// P8.
  Future<void> deleteUnit(String productId, String unitId) =>
      _dio.delete<Object?>(ApiPaths.productUnit(productId, unitId));

  /// P9.
  Future<StockMovementDto> adjustStock(
    String productId,
    AdjustmentRequestDto request,
  ) async {
    final response = await _dio.post<Object?>(
      ApiPaths.productAdjustments(productId),
      data: request.toJson(),
    );
    return StockMovementDto.fromJson(requireJsonObject(response.data));
  }

  /// P10.
  Future<StockCountResponseDto> recordStockCount(
    String productId,
    StockCountRequestDto request,
  ) async {
    final response = await _dio.post<Object?>(
      ApiPaths.productStockCounts(productId),
      data: request.toJson(),
    );
    return StockCountResponseDto.fromJson(requireJsonObject(response.data));
  }

  /// P11.
  Future<PagedResponseDto<StockMovementDto>> getMovements(
    String productId, {
    required int page,
    required int pageSize,
  }) async {
    final response = await _dio.get<Object?>(
      ApiPaths.productMovements(productId),
      queryParameters: {ApiQuery.page: page, ApiQuery.pageSize: pageSize},
    );
    return PagedResponseDto.parse(response.data, StockMovementDto.fromJson);
  }

  /// P12.
  Future<ProductLookupResponseDto> lookupBarcode(String barcode) async {
    final response = await _dio.get<Object?>(
      ApiPaths.productLookup,
      queryParameters: {ApiQuery.barcode: barcode},
    );
    return ProductLookupResponseDto.fromJson(requireJsonObject(response.data));
  }
}
