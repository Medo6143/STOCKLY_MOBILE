import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/products/data/datasources/products_remote_data_source.dart';
import 'package:stockly/features/products/data/models/product_mapper.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_lookup.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_count_result.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

final class ProductsRepositoryImpl implements ProductsRepository {
  const new(this._remote);

  final ProductsRemoteDataSource _remote;

  @override
  Future<Result<Paged<ProductListItem>, Failure>> getProducts(
    ProductQuery query, {
    required int page,
    required int pageSize,
  }) => safeApiCall(() async {
    final response = await _remote.getProducts(
      search: query.searchOrNull,
      lowStock: query.lowStock,
      includeArchived: query.includeArchived,
      page: page,
      pageSize: pageSize,
    );
    return response.toPaged((item) => item.toEntity());
  });

  @override
  Future<Result<ProductDetail, Failure>> getProduct(String productId) =>
      safeApiCall(() async => (await _remote.getProduct(productId)).toEntity());

  @override
  Future<Result<ProductDetail, Failure>> createProduct(ProductDraft draft) =>
      safeApiCall(
        () async => (await _remote.createProduct(draft.toRequest())).toEntity(),
      );

  @override
  Future<Result<ProductDetail, Failure>> updateProduct(
    String productId,
    ProductUpdate update,
  ) => safeApiCall(
    () async =>
        (await _remote.updateProduct(productId, update.toRequest())).toEntity(),
  );

  @override
  Future<Result<void, Failure>> archiveProduct(String productId) =>
      safeApiCall(() => _remote.archiveProduct(productId));

  @override
  Future<Result<ProductUnit, Failure>> addUnit(
    String productId,
    UnitDraft draft,
  ) => safeApiCall(
    () async =>
        (await _remote.addUnit(productId, draft.toRequest())).toEntity(),
  );

  @override
  Future<Result<ProductUnit, Failure>> updateUnit(
    String productId,
    String unitId,
    UnitDraft draft,
  ) => safeApiCall(
    () async => (await _remote.updateUnit(
      productId,
      unitId,
      draft.toRequest(),
    )).toEntity(),
  );

  @override
  Future<Result<void, Failure>> deleteUnit(String productId, String unitId) =>
      safeApiCall(() => _remote.deleteUnit(productId, unitId));

  @override
  Future<Result<StockMovement, Failure>> adjustStock(
    String productId,
    StockAdjustmentDraft draft,
  ) => safeApiCall(
    () async =>
        (await _remote.adjustStock(productId, draft.toRequest())).toEntity(),
  );

  @override
  Future<Result<StockCountResult, Failure>> recordStockCount(
    String productId,
    StockCountDraft draft,
  ) => safeApiCall(
    () async => (await _remote.recordStockCount(
      productId,
      draft.toRequest(),
    )).toEntity(),
  );

  @override
  Future<Result<Paged<StockMovement>, Failure>> getMovements(
    String productId, {
    required int page,
    required int pageSize,
  }) => safeApiCall(() async {
    final response = await _remote.getMovements(
      productId,
      page: page,
      pageSize: pageSize,
    );
    return response.toPaged((item) => item.toEntity());
  });

  @override
  Future<Result<ProductLookup, Failure>> lookupBarcode(String barcode) =>
      safeApiCall(
        () async => (await _remote.lookupBarcode(barcode)).toEntity(),
      );
}
