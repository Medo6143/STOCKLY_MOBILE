import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/products/domain/entities/product_base_unit.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_count_result.dart';
import 'package:stockly/features/products/domain/entities/stock_movement.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/products/domain/repositories/products_repository.dart';

class MockProductsRepository extends Mock implements ProductsRepository;

const String productId = '0192f0a0-6c1e-7b3a-9d2e-a00000000001';
const String baseUnitId = '0192f0a0-6c1e-7b3a-9d2e-b00000000002';
const String boxUnitId = '0192f0a0-6c1e-7b3a-9d2e-b00000000003';
const String userId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d02';

Money money(String raw) => Money.fromApi(raw);
Quantity quantity(String raw) => Quantity.fromApi(raw);

ProductListItem listItem({
  String id = productId,
  String name = 'بنادول اكسترا',
  String qty = '24.000',
  String threshold = '5.000',
  bool isLowStock = false,
  bool isArchived = false,
}) => ProductListItem(
  id: id,
  name: name,
  quantity: quantity(qty),
  baseUnit: ProductBaseUnit(
    id: baseUnitId,
    name: 'شريط',
    sellPrice: money('15.00'),
  ),
  lowStockThreshold: quantity(threshold),
  isLowStock: isLowStock,
  isArchived: isArchived,
);

final ProductUnit baseUnit = ProductUnit(
  id: baseUnitId,
  name: 'شريط',
  factor: UnitFactor.fromApi('1.000000'),
  sellPrice: money('15.00'),
  barcode: null,
  isBase: true,
);

final ProductUnit boxUnit = ProductUnit(
  id: boxUnitId,
  name: 'علبة',
  factor: UnitFactor.fromApi('3.000000'),
  sellPrice: money('40.00'),
  barcode: '6221234567906',
  isBase: false,
);

ProductDetail detail({
  String qty = '24.000',
  bool isLowStock = false,
  bool isArchived = false,
  List<ProductUnit>? units,
}) => ProductDetail(
  id: productId,
  name: 'بنادول اكسترا',
  barcode: '6221234567890',
  category: 'مسكنات',
  quantity: quantity(qty),
  costPrice: money('12.50'),
  lowStockThreshold: quantity('5.000'),
  isLowStock: isLowStock,
  isArchived: isArchived,
  units: units ?? [baseUnit, boxUnit],
  createdAt: DateTime.utc(2026, 10, 12, 7),
  updatedAt: DateTime.utc(2026, 10, 12, 7),
);

StockMovement movement({
  String id = '0192f0a0-6c1e-7b3a-9d2e-c00000000001',
  String change = '-2.000',
  String balance = '22.000',
  StockMovementReason reason = StockMovementReason.manualAdjustment,
  String? note = 'Expired, thrown away',
  String? invoiceId,
  String? saleId,
}) => StockMovement(
  id: id,
  productId: productId,
  quantityChange: quantity(change),
  balanceAfter: quantity(balance),
  reason: reason,
  invoiceId: invoiceId,
  saleId: saleId,
  note: note,
  createdByUserId: userId,
  createdAt: DateTime.utc(2026, 10, 12, 7),
);

Paged<T> page<T>(List<T> items, {int page = 1, int? totalCount}) => Paged(
  items: items,
  page: page,
  pageSize: 20,
  totalCount: totalCount ?? items.length,
);

ApiProblemInfo info(int status) =>
    ApiProblemInfo(status: status, traceId: '00-trace-00');

const NotFoundFailure productNotFound = NotFoundFailure(
  ApiErrorCode.productNotFound,
  ApiProblemInfo(status: HttpStatus.notFound),
);

ConflictFailure conflict(ApiErrorCode code) =>
    ConflictFailure(code, info(HttpStatus.conflict));

InvalidInputFailure invalidInput(ApiErrorCode code) =>
    InvalidInputFailure(code, info(HttpStatus.badRequest));

const ForbiddenFailure forbidden = ForbiddenFailure(
  ApiErrorCode.authForbidden,
  ApiProblemInfo(status: HttpStatus.forbidden),
);

/// Registers mocktail fallbacks once per test file.
void registerProductFallbacks() {
  registerFallbackValue(const ProductQuery());
  registerFallbackValue(
    ProductDraft(
      name: 'x',
      barcode: null,
      category: null,
      baseUnitName: 'x',
      costPrice: Money.zero,
      baseUnitSellPrice: Money.zero,
      lowStockThreshold: null,
      openingQuantity: null,
    ),
  );
  registerFallbackValue(
    ProductUpdate(
      name: 'x',
      barcode: null,
      category: null,
      costPrice: Money.zero,
      lowStockThreshold: Quantity.zero,
    ),
  );
  registerFallbackValue(
    UnitDraft(
      name: 'x',
      factor: UnitFactor.fromApi('1.000000'),
      sellPrice: Money.zero,
      barcode: null,
    ),
  );
  registerFallbackValue(
    StockAdjustmentDraft(
      quantityChange: Quantity.zero,
      unitId: null,
      note: 'x',
    ),
  );
  registerFallbackValue(
    StockCountDraft(countedQuantity: Quantity.zero, unitId: null),
  );
}

/// A repository whose catalogue is empty, for tests of other screens that
/// land on the product list.
MockProductsRepository emptyCatalog() {
  registerFallbackValue(const ProductQuery());
  final repository = MockProductsRepository();
  when(
    () => repository.getProducts(
      any(),
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((_) async => Ok(page<ProductListItem>(const [])));
  return repository;
}

/// A stock count result.
StockCountResult countResult({required bool changed, String qty = '26.000'}) =>
    StockCountResult(
      changed: changed,
      quantity: quantity(qty),
      movement: changed
          ? movement(
              change: '2.000',
              balance: qty,
              reason: StockMovementReason.stockCount,
              note: null,
            )
          : null,
    );

/// The value of an [Ok] result.
T okValue<T>(Result<T, Failure> result) => (result as Ok<T, Failure>).value;

/// The failure of an [Err] result.
Failure errOf(Result<Object?, Failure> result) =>
    (result as Err<Object?, Failure>).failure;
