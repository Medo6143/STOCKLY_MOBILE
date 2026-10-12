import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
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

/// Contract P1–P12. The shop always comes from the access token.
abstract interface class ProductsRepository {
  /// P1.
  Future<Result<Paged<ProductListItem>, Failure>> getProducts(
    ProductQuery query, {
    required int page,
    required int pageSize,
  });

  /// P2.
  Future<Result<ProductDetail, Failure>> getProduct(String productId);

  /// P3.
  Future<Result<ProductDetail, Failure>> createProduct(ProductDraft draft);

  /// P4.
  Future<Result<ProductDetail, Failure>> updateProduct(
    String productId,
    ProductUpdate update,
  );

  /// P5 (Owner).
  Future<Result<void, Failure>> archiveProduct(String productId);

  /// P6.
  Future<Result<ProductUnit, Failure>> addUnit(
    String productId,
    UnitDraft draft,
  );

  /// P7.
  Future<Result<ProductUnit, Failure>> updateUnit(
    String productId,
    String unitId,
    UnitDraft draft,
  );

  /// P8.
  Future<Result<void, Failure>> deleteUnit(String productId, String unitId);

  /// P9 (Owner).
  Future<Result<StockMovement, Failure>> adjustStock(
    String productId,
    StockAdjustmentDraft draft,
  );

  /// P10 (Owner).
  Future<Result<StockCountResult, Failure>> recordStockCount(
    String productId,
    StockCountDraft draft,
  );

  /// P11, newest first.
  Future<Result<Paged<StockMovement>, Failure>> getMovements(
    String productId, {
    required int page,
    required int pageSize,
  });

  /// P12.
  Future<Result<ProductLookup, Failure>> lookupBarcode(String barcode);
}
