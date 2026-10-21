import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/features/products/data/datasources/products_remote_data_source.dart';
import 'package:stockly/features/products/data/repositories/products_repository_impl.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';

import '../../../contract/json_shape.dart';
import '../../../helpers/products_doubles.dart';
import '../../../helpers/scripted_adapter.dart';
import '../../../helpers/test_app.dart';

/// The data layer of products: request bodies use the contract's decimal
/// strings, responses that break the contract become
/// `MalformedResponseFailure`, problems map by `code`.
void main() {
  late ScriptedAdapter adapter;
  late ProductsRepositoryImpl repository;

  setUp(() {
    adapter = ScriptedAdapter((_) async => jsonBody(200, const {}));
    repository = ProductsRepositoryImpl(
      ProductsRemoteDataSource(rawDio(adapter)),
    );
  });

  Object? lastBody() {
    final data = adapter.requests.last.data;
    return data is String ? jsonDecode(data) : data;
  }

  test('GetProducts_SendsTheQuery_ParsesThePage', () async {
    adapter.respond = (_) async => jsonBody(200, fixture('product_list_page'));

    final result = await repository.getProducts(
      const ProductQuery(search: ' بنادول ', lowStock: true),
      page: 2,
      pageSize: 20,
    );

    final query = adapter.requests.single.uri.queryParameters;
    expect(query, {
      'search': 'بنادول',
      'lowStock': 'true',
      'page': '2',
      'pageSize': '20',
    });
    final value = okValue(result);
    expect(value.totalCount, 137);
    expect(value.items.single.quantity, quantity('24.000'));
    expect(value.items.single.baseUnit.sellPrice, money('15.00'));
  });

  test('GetProducts_BlankSearchAndNoFilters_NotSent', () async {
    adapter.respond = (_) async => jsonBody(200, fixture('product_list_page'));

    await repository.getProducts(
      const ProductQuery(search: '  '),
      page: 1,
      pageSize: 20,
    );

    expect(adapter.requests.single.uri.queryParameters, {
      'page': '1',
      'pageSize': '20',
    });
  });

  test('CreateProduct_SendsDecimalStringsAndOmitsAbsentOptionals', () async {
    adapter.respond = (_) async => jsonBody(201, fixture('product_detail'));

    final result = await repository.createProduct(
      ProductDraft(
        name: 'بنادول اكسترا',
        barcode: null,
        category: null,
        baseUnitName: 'شريط',
        costPrice: money('12.50'),
        baseUnitSellPrice: money('15.00'),
        lowStockThreshold: null,
        openingQuantity: quantity('24.000'),
      ),
    );

    expect(result, isA<Ok<Object?, Failure>>());
    expect(lastBody(), {
      'name': 'بنادول اكسترا',
      'baseUnitName': 'شريط',
      'costPrice': '12.50',
      'baseUnitSellPrice': '15.00',
      'openingQuantity': '24.000',
    });
    final detail = okValue(result);
    expect(detail.units.first.isBase, isTrue);
  });

  test('Units_Adjust_Count_RequestBodiesMatchTheContract', () async {
    adapter.respond = (options) async => switch (options.path) {
      final path when path.endsWith('/units') => jsonBody(
        201,
        fixture('unit_dto'),
      ),
      final path when path.endsWith('/adjustments') => jsonBody(
        201,
        fixture('stock_movement'),
      ),
      _ => jsonBody(200, fixture('stock_count_response')),
    };

    await repository.addUnit(
      productId,
      UnitDraft(
        name: 'علبة',
        factor: boxUnit.factor,
        sellPrice: money('40.00'),
        barcode: null,
      ),
    );
    expect(lastBody(), fixture('unit_request'));

    final moved = await repository.adjustStock(
      productId,
      StockAdjustmentDraft(
        quantityChange: quantity('-2.000'),
        unitId: null,
        note: 'Expired, thrown away',
      ),
    );
    expect(lastBody(), fixture('adjustment_request'));
    expect(okValue(moved).reason, StockMovementReason.manualAdjustment);

    final counted = await repository.recordStockCount(
      productId,
      StockCountDraft(countedQuantity: quantity('26.000'), unitId: null),
    );
    expect(lastBody(), fixture('stock_count_request'));
    expect(okValue(counted).changed, isTrue);
    expect(adapter.requests.map((r) => r.path), [
      ApiPaths.productUnits(productId),
      ApiPaths.productAdjustments(productId),
      ApiPaths.productStockCounts(productId),
    ]);
  });

  test('Malformed_NumberInsteadOfDecimalString_MalformedResponse', () async {
    adapter.respond = (_) async =>
        jsonBody(200, fixture('product_detail')..['quantity'] = 24);

    final result = await repository.getProduct(productId);

    expect(errOf(result), isA<MalformedResponseFailure>());
  });

  test('Malformed_WrongScaleOrUnknownReasonOrNoBaseUnit', () async {
    final unknownReason = fixture('movement_page');
    ((unknownReason['items']! as List<Object?>).first!
            as Map<String, Object?>)['reason'] =
        'Theft';
    final noBase = fixture('product_detail')..['units'] = [fixture('unit_dto')];
    for (final body in [
      fixture('product_detail')..['costPrice'] = '12.505',
      noBase,
    ]) {
      adapter.respond = (_) async => jsonBody(200, body);
      final result = await repository.getProduct(productId);
      expect(errOf(result), isA<MalformedResponseFailure>());
    }
    adapter.respond = (_) async => jsonBody(200, unknownReason);
    final movements = await repository.getMovements(
      productId,
      page: 1,
      pageSize: 20,
    );
    expect(errOf(movements), isA<MalformedResponseFailure>());
  });

  test('Problems_MapByCode', () async {
    for (final (status, code, type) in [
      (HttpStatus.notFound, 'Product.NotFound', NotFoundFailure),
      (HttpStatus.conflict, 'ProductUnit.InUse', ConflictFailure),
      (HttpStatus.forbidden, 'Auth.Forbidden', ForbiddenFailure),
      (HttpStatus.forbidden, 'Product.OpeningStockOwnerOnly', ForbiddenFailure),
      (HttpStatus.badRequest, 'Stock.ZeroChange', InvalidInputFailure),
    ]) {
      adapter.respond = (_) async => problemBody(status, code);
      final result = await repository.deleteUnit(productId, boxUnitId);
      final failure = errOf(result) as ApiFailure;
      expect(failure.runtimeType, type, reason: code);
      expect(failure.code, ApiErrorCode.fromWire(code));
    }
  });

  test('Archive_And_Lookup_Paths', () async {
    adapter.respond = (options) async => options.method == 'POST'
        ? ResponseBody.fromString('', HttpStatus.noContent)
        : jsonBody(200, fixture('product_lookup_response'));

    final archived = await repository.archiveProduct(productId);
    final lookup = await repository.lookupBarcode('6221234567890');

    expect(archived, isA<Ok<void, Failure>>());
    expect(okValue(lookup).unit.isBase, isTrue);
    expect(adapter.requests.first.path, ApiPaths.productArchive(productId));
    expect(adapter.requests.last.uri.queryParameters, {
      'barcode': '6221234567890',
    });
    expect(adapter.requests.last.method, 'GET');
  });
}
