import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_paging.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/products/domain/usecases/add_unit_use_case.dart';
import 'package:stockly/features/products/domain/usecases/adjust_stock_use_case.dart';
import 'package:stockly/features/products/domain/usecases/archive_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/create_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/delete_unit_use_case.dart';
import 'package:stockly/features/products/domain/usecases/get_movements_use_case.dart';
import 'package:stockly/features/products/domain/usecases/get_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/get_products_use_case.dart';
import 'package:stockly/features/products/domain/usecases/lookup_barcode_use_case.dart';
import 'package:stockly/features/products/domain/usecases/record_stock_count_use_case.dart';
import 'package:stockly/features/products/domain/usecases/update_product_use_case.dart';
import 'package:stockly/features/products/domain/usecases/update_unit_use_case.dart';

import '../../../helpers/products_doubles.dart';

/// Every products use case: the happy path and each mapped failure it can
/// return passes through unchanged (design §13.1).
void main() {
  late MockProductsRepository repository;

  setUpAll(registerProductFallbacks);
  setUp(() => repository = MockProductsRepository());

  final draft = ProductDraft(
    name: 'x',
    barcode: null,
    category: null,
    baseUnitName: 'y',
    costPrice: money('1.00'),
    baseUnitSellPrice: money('2.00'),
    lowStockThreshold: null,
    openingQuantity: quantity('3.000'),
  );
  final update = ProductUpdate(
    name: 'x',
    barcode: null,
    category: null,
    costPrice: money('1.00'),
    lowStockThreshold: quantity('0.000'),
  );
  final unitDraft = UnitDraft(
    name: 'علبة',
    factor: boxUnit.factor,
    sellPrice: money('40.00'),
    barcode: null,
  );
  final adjustment = StockAdjustmentDraft(
    quantityChange: quantity('-2.000'),
    unitId: null,
    note: 'n',
  );
  final count = StockCountDraft(
    countedQuantity: quantity('26.000'),
    unitId: null,
  );

  test('GetProducts_PassesQueryAndPageSize20', () async {
    const query = ProductQuery(search: 'بنادول', lowStock: true);
    when(() => repository.getProducts(query, page: 2, pageSize: 20))
        .thenAnswer((_) async => Ok(page([listItem()], page: 2)));

    final result = await GetProductsUseCase(repository).call(query, page: 2);

    expect(okValue(result).items, [listItem()]);
    expect(ProductPaging.pageSize, 20);
  });

  test('GetProduct_NotFound_PassesThrough', () async {
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => const Err(productNotFound));

    final result = await GetProductUseCase(repository).call(productId);

    expect(errOf(result), productNotFound);
  });

  test('GetProduct_Ok', () async {
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => Ok(detail()));

    final result = await GetProductUseCase(repository).call(productId);

    expect(okValue(result), detail());
  });

  test('CreateProduct_OkAndConflictAndForbidden', () async {
    final useCase = CreateProductUseCase(repository);
    when(() => repository.createProduct(draft))
        .thenAnswer((_) async => Ok(detail()));
    expect(await useCase(draft), isA<Ok<Object?, Failure>>());

    for (final failure in <Failure>[
      conflict(ApiErrorCode.productDuplicateBarcode),
      const ForbiddenFailure(
        ApiErrorCode.productOpeningStockOwnerOnly,
        ApiProblemInfo(status: 403),
      ),
      invalidInput(ApiErrorCode.productNameRequired),
    ]) {
      when(() => repository.createProduct(draft))
          .thenAnswer((_) async => Err(failure));
      expect(errOf(await useCase(draft)), failure);
    }
  });

  test('UpdateProduct_OkAndArchived', () async {
    final useCase = UpdateProductUseCase(repository);
    when(() => repository.updateProduct(productId, update))
        .thenAnswer((_) async => Ok(detail()));
    expect(await useCase(productId, update), isA<Ok<Object?, Failure>>());

    final archived = conflict(ApiErrorCode.productArchived);
    when(() => repository.updateProduct(productId, update))
        .thenAnswer((_) async => Err(archived));
    expect(errOf(await useCase(productId, update)), archived);
  });

  test('ArchiveProduct_OkAndForbidden', () async {
    final useCase = ArchiveProductUseCase(repository);
    when(() => repository.archiveProduct(productId))
        .thenAnswer((_) async => const Ok(null));
    expect(await useCase(productId), isA<Ok<void, Failure>>());

    when(() => repository.archiveProduct(productId))
        .thenAnswer((_) async => const Err(forbidden));
    expect(errOf(await useCase(productId)), forbidden);
  });

  test('Units_AddUpdateDelete_PassThrough', () async {
    when(() => repository.addUnit(productId, unitDraft))
        .thenAnswer((_) async => Ok(boxUnit));
    when(() => repository.updateUnit(productId, boxUnitId, unitDraft))
        .thenAnswer(
          (_) async => Err(conflict(ApiErrorCode.productUnitDuplicateName)),
        );
    when(() => repository.deleteUnit(productId, boxUnitId))
        .thenAnswer((_) async => Err(conflict(ApiErrorCode.productUnitInUse)));

    expect(
      okValue(await AddUnitUseCase(repository)(productId, unitDraft)),
      boxUnit,
    );
    expect(
      errOf(
        await UpdateUnitUseCase(repository)(productId, boxUnitId, unitDraft),
      ) as ApiFailure,
      isA<ConflictFailure>(),
    );
    expect(
      (errOf(
        await DeleteUnitUseCase(repository)(productId, boxUnitId),
      ) as ApiFailure).code,
      ApiErrorCode.productUnitInUse,
    );
  });

  test('AdjustStock_OkAndZeroChange', () async {
    final useCase = AdjustStockUseCase(repository);
    when(() => repository.adjustStock(productId, adjustment))
        .thenAnswer((_) async => Ok(movement()));
    expect(okValue(await useCase(productId, adjustment)), movement());

    final zero = invalidInput(ApiErrorCode.stockZeroChange);
    when(() => repository.adjustStock(productId, adjustment))
        .thenAnswer((_) async => Err(zero));
    expect(errOf(await useCase(productId, adjustment)), zero);
  });

  test('RecordStockCount_UnchangedAndNotFound', () async {
    final useCase = RecordStockCountUseCase(repository);
    when(() => repository.recordStockCount(productId, count))
        .thenAnswer((_) async => Ok(countResult(changed: false)));
    expect(
      okValue(await useCase(productId, count)),
      countResult(changed: false),
    );

    when(() => repository.recordStockCount(productId, count))
        .thenAnswer((_) async => const Err(productNotFound));
    expect(errOf(await useCase(productId, count)), productNotFound);
  });

  test('GetMovements_PageSize20', () async {
    when(() => repository.getMovements(productId, page: 1, pageSize: 20))
        .thenAnswer((_) async => Ok(page([movement()])));

    final result = await GetMovementsUseCase(repository)(productId, page: 1);

    expect(okValue(result).items, [movement()]);
  });

  test('LookupBarcode_TrimsTheBarcode', () async {
    when(() => repository.lookupBarcode('622'))
        .thenAnswer((_) async => const Err(productNotFound));

    final result = await LookupBarcodeUseCase(repository)(' 622 ');

    expect(errOf(result), productNotFound);
  });
}
