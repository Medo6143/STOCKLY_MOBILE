import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/seed/fake_product_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/features/products/data/datasources/products_remote_data_source.dart';
import 'package:stockly/features/products/data/repositories/products_repository_impl.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';

import '../helpers/fake_app.dart';
import '../helpers/products_doubles.dart' show okValue;
import '../helpers/test_doubles.dart';
import 'json_shape.dart';

/// Contract P1–P12 (v1.4 §5) against the fake backend: status codes, error
/// codes, decimal scales and JSON shapes from the contract fixtures.
void main() {
  late FakeClock clock;
  late FakeBackendState state;
  late FakeBackendAdapter adapter;
  late Dio dio;
  late String owner;
  late String staff;

  Future<String> tokenOf(String email) async =>
      (await loginOn(adapter, email: email)).accessToken;

  setUp(() async {
    clock = FakeClock();
    state = FakeSeed.pharmacy(clock.now());
    adapter = fakeBackend(clock: clock, state: state);
    dio = rawDio(adapter)..options.validateStatus = ((_) => true);
    owner = await tokenOf(FakeSeed.ownerEmail);
    staff = await tokenOf(FakeSeed.staffEmail);
  });

  Options auth(String? token, {String language = 'en'}) => Options(
    headers: {
      HttpHeaderNames.acceptLanguage: language,
      if (token != null)
        HttpHeaderNames.authorization: '${HttpHeaderNames.bearerPrefix}$token',
    },
  );

  Future<Response<Object?>> get(
    String path, {
    String? token,
    Map<String, Object?>? query,
  }) => dio.get<Object?>(
    path,
    queryParameters: query,
    options: auth(token ?? owner),
  );

  Future<Response<Object?>> post(String path, Object? body, {String? token}) =>
      dio.post<Object?>(path, data: body, options: auth(token ?? owner));

  Future<Response<Object?>> put(String path, Object? body, {String? token}) =>
      dio.put<Object?>(path, data: body, options: auth(token ?? owner));

  Future<Response<Object?>> delete(String path, {String? token}) =>
      dio.delete<Object?>(path, options: auth(token ?? owner));

  Map<String, Object?> json(Response<Object?> response) =>
      response.data! as Map<String, Object?>;

  List<Map<String, Object?>> items(Response<Object?> response) => [
    for (final item in json(response)['items']! as List<Object?>)
      item! as Map<String, Object?>,
  ];

  void expectProblem(Response<Object?> response, int status, String code) {
    expect(response.statusCode, status, reason: '${response.data}');
    expect(
      response.headers.value(Headers.contentTypeHeader),
      startsWith('application/problem+json'),
    );
    final body = json(response);
    expect(body['code'], code);
    expect(body['status'], status);
    final keys = fixture('problem_details').keys.toSet();
    expect(
      body.keys.toSet(),
      code == 'Validation.Failed' ? {...keys, 'errors'} : keys,
    );
  }

  FakeProduct seeded(String name) =>
      state.products.firstWhere((p) => p.name == name);

  FakeProduct panadol() => seeded('بنادول اكسترا');

  String randomId() => '0192f0a0-6c1e-7b3a-9d2e-ffffffffffff';

  Map<String, Object?> createBody({
    String name = 'سيتال شراب',
    Object? barcode,
    Object? opening,
    Object? costPrice = '20.50',
  }) => {
    'name': name,
    'barcode': ?barcode,
    'category': 'مسكنات',
    'baseUnitName': 'زجاجة',
    'costPrice': costPrice,
    'baseUnitSellPrice': '25.00',
    'lowStockThreshold': '2.000',
    'openingQuantity': ?opening,
  };

  group('every products endpoint', () {
    test('NoToken_401Unauthenticated', () async {
      final response = await dio.get<Object?>(
        ApiPaths.products,
        options: auth(null),
      );

      expectProblem(response, 401, 'Auth.Unauthenticated');
    });

    test('SuspendedShop_403ShopSuspended', () async {
      state.shops.single.status = FakeShopStatuses.suspended;

      final response = await get(ApiPaths.product(panadol().id));

      expectProblem(response, 403, 'Shop.Suspended');
    });

    test('NonUuidId_404HttpNotFound', () async {
      final response = await get('${ApiPaths.products}/p1');

      expectProblem(response, 404, 'Http.NotFound');
    });

    test('WrongMethod_405', () async {
      final response = await delete(ApiPaths.products);

      expectProblem(response, 405, 'Http.MethodNotAllowed');
    });
  });

  group('P1 GET /api/products', () {
    test('List_Default_200PagedSortedByNameWithoutArchived', () async {
      final response = await get(ApiPaths.products);

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('product_list_page'));
      final body = json(response);
      final active = state.products.where((p) => !p.isArchived).length;
      expect(body['totalCount'], active);
      expect(body['page'], 1);
      expect(body['pageSize'], 20);
      expect(items(response), hasLength(20));
      expect(items(response).any((i) => i['isArchived'] == true), isFalse);
    });

    test('List_SecondPage_HasTheRest', () async {
      final response = await get(
        ApiPaths.products,
        query: {'page': 2, 'pageSize': 20},
      );

      final active = state.products.where((p) => !p.isArchived).length;
      expect(items(response), hasLength(active - 20));
    });

    test('List_IncludeArchived_ShowsTheArchivedProduct', () async {
      final response = await get(
        ApiPaths.products,
        query: {'includeArchived': true, 'pageSize': 100},
      );

      expect(json(response)['totalCount'], state.products.length);
      expect(
        items(response).where((i) => i['isArchived'] == true),
        hasLength(1),
      );
    });

    test('List_LowStock_OnlyAtOrBelowThresholdIncludingNegative', () async {
      final response = await get(
        ApiPaths.products,
        query: {'lowStock': true, 'pageSize': 100},
      );

      final rows = items(response);
      expect(rows, isNotEmpty);
      expect(rows.every((i) => i['isLowStock'] == true), isTrue);
      expect(
        rows.any((i) => (i['quantity']! as String).startsWith('-')),
        isTrue,
      );
    });

    test('List_SearchArabicNormalized_MatchesHamzaAndTaMarbuta', () async {
      // "أدفانس" is stored with hamza; "ادفانس" finds it.
      final response = await get(
        ApiPaths.products,
        query: {'search': 'ادفانس'},
      );

      expect(items(response).map((i) => i['name']), ['بنادول أدفانس']);
    });

    test('List_PageSizeOver100_400ValidationFailed', () async {
      final response = await get(ApiPaths.products, query: {'pageSize': 101});

      expectProblem(response, 400, 'Validation.Failed');
    });

    test('List_SearchOver100Chars_400ValidationFailed', () async {
      final response = await get(
        ApiPaths.products,
        query: {'search': 'x' * 101},
      );

      expectProblem(response, 400, 'Validation.Failed');
    });
  });

  group('P2 GET /api/products/{id}', () {
    test('Get_Existing_200ProductDetailBaseUnitFirst', () async {
      final response = await get(ApiPaths.product(panadol().id));

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('product_detail'));
      final units = json(response)['units']! as List<Object?>;
      expect((units.first! as Map<String, Object?>)['isBase'], isTrue);
      expect(json(response)['quantity'], '24.000');
    });

    test('Get_Unknown_404ProductNotFound', () async {
      final response = await get(ApiPaths.product(randomId()));

      expectProblem(response, 404, 'Product.NotFound');
    });

    test('Get_OtherShopsProduct_404ProductNotFound', () async {
      panadol();
      state.products.add(
        FakeProduct(
          id: randomId(),
          shopId: '0192f0a0-6c1e-7b3a-9d2e-eeeeeeeeeeee',
          name: 'x',
          barcode: null,
          category: null,
          costPrice: Decimal.one,
          lowStockThreshold: Decimal.zero,
          units: [
            FakeUnit(
              id: '0192f0a0-6c1e-7b3a-9d2e-dddddddddddd',
              name: 'x',
              factor: Decimal.one,
              sellPrice: Decimal.one,
              barcode: null,
              isBase: true,
            ),
          ],
          createdAt: clock.now(),
        ),
      );

      final response = await get(ApiPaths.product(randomId()));

      expectProblem(response, 404, 'Product.NotFound');
    });
  });

  group('P3 POST /api/products', () {
    test('Create_ContractExample_201WithOpeningStockMovement', () async {
      final response = await post(
        ApiPaths.products,
        fixture('create_product_request')..['barcode'] = '6220000000001',
      );

      expect(response.statusCode, HttpStatus.created);
      expectSameShape(json(response), fixture('product_detail'));
      final id = json(response)['id']! as String;
      expect(response.headers.value('location'), ApiPaths.product(id));
      expect(json(response)['quantity'], '24.000');
      final movements = await get(ApiPaths.productMovements(id));
      final opening = items(movements).single;
      expect(opening['reason'], 'StockCount');
      expect(opening['note'], FakeMovementReasons.openingStockNote);
      expect(opening['quantityChange'], '24.000');
    });

    test('Create_NoOpening_StartsAtZeroWithoutMovement', () async {
      final response = await post(ApiPaths.products, createBody());

      expect(response.statusCode, HttpStatus.created);
      expect(json(response)['quantity'], '0.000');
      final id = json(response)['id']! as String;
      final movements = await get(ApiPaths.productMovements(id));
      expect(items(movements), isEmpty);
    });

    test('Create_StaffWithOpening_403OpeningStockOwnerOnly', () async {
      final before = state.products.length;

      final response = await post(
        ApiPaths.products,
        createBody(opening: '5.000'),
        token: staff,
      );

      expectProblem(response, 403, 'Product.OpeningStockOwnerOnly');
      expect(state.products, hasLength(before));
    });

    test('Create_StaffWithoutOpening_201', () async {
      final response = await post(
        ApiPaths.products,
        createBody(),
        token: staff,
      );

      expect(response.statusCode, HttpStatus.created);
    });

    test('Create_BlankNames_400NameRequiredCodes', () async {
      expectProblem(
        await post(ApiPaths.products, createBody(name: ' ـ ')),
        400,
        'Product.NameRequired',
      );
      expectProblem(
        await post(ApiPaths.products, createBody()..['baseUnitName'] = '  '),
        400,
        'ProductUnit.NameRequired',
      );
    });

    test('Create_Precision_400PrecisionCodesNeverRounded', () async {
      for (final (cost, code) in [
        ('1.234', 'Precision.TooManyDecimals'),
        ('-1.00', 'Precision.Negative'),
        ('99999999999999999', 'Precision.OutOfRange'),
      ]) {
        expectProblem(
          await post(ApiPaths.products, createBody(costPrice: cost)),
          400,
          code,
        );
      }
    });

    test('Create_JsonNumberOrMissingDecimal_400ValidationFailed', () async {
      expectProblem(
        await post(ApiPaths.products, createBody(costPrice: 12.5)),
        400,
        'Validation.Failed',
      );
      expectProblem(
        await post(ApiPaths.products, createBody(costPrice: null)),
        400,
        'Validation.Failed',
      );
    });

    test('Create_DuplicateBarcode_409', () async {
      final response = await post(
        ApiPaths.products,
        createBody(barcode: FakeProductSeed.panadolBarcode),
      );

      expectProblem(response, 409, 'Product.DuplicateBarcode');
    });
  });

  group('P4 PUT /api/products/{id}', () {
    Map<String, Object?> body({String? barcode}) => {
      'name': 'بنادول اكسترا 24',
      'barcode': barcode,
      'category': null,
      'costPrice': '13.00',
      'lowStockThreshold': '6.000',
    };

    test('Update_Valid_200ProductDetail', () async {
      final response = await put(ApiPaths.product(panadol().id), body());

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('product_detail'));
      expect(json(response)['name'], 'بنادول اكسترا 24');
      expect(json(response)['costPrice'], '13.00');
      expect(json(response)['category'], isNull);
    });

    test('Update_OwnBarcode_Allowed_OthersBarcode_409', () async {
      final own = await put(
        ApiPaths.product(panadol().id),
        body(barcode: FakeProductSeed.panadolBarcode),
      );
      final other = await put(
        ApiPaths.product(seeded('كونجستال').id),
        body(barcode: FakeProductSeed.panadolBarcode),
      );

      expect(own.statusCode, HttpStatus.ok);
      expectProblem(other, 409, 'Product.DuplicateBarcode');
    });

    test('Update_Archived_409ProductArchived', () async {
      final response = await put(
        ApiPaths.product(seeded('فيفادول').id),
        body(),
      );

      expectProblem(response, 409, 'Product.Archived');
    });

    test('Update_MissingThreshold_400ValidationFailed', () async {
      final response = await put(
        ApiPaths.product(panadol().id),
        body()..remove('lowStockThreshold'),
      );

      expectProblem(response, 400, 'Validation.Failed');
    });

    test('Update_Unknown_404', () async {
      final response = await put(ApiPaths.product(randomId()), body());

      expectProblem(response, 404, 'Product.NotFound');
    });
  });

  group('P5 POST /api/products/{id}/archive', () {
    test('Archive_Owner_204Idempotent', () async {
      final id = panadol().id;

      final first = await post(ApiPaths.productArchive(id), null);
      final second = await post(ApiPaths.productArchive(id), null);

      expect(first.statusCode, HttpStatus.noContent);
      expect(second.statusCode, HttpStatus.noContent);
      expect(panadol().isArchived, isTrue);
    });

    test('Archive_Staff_403AuthForbidden', () async {
      final response = await post(
        ApiPaths.productArchive(panadol().id),
        null,
        token: staff,
      );

      expectProblem(response, 403, 'Auth.Forbidden');
    });

    test('Archive_Unknown_404', () async {
      final response = await post(ApiPaths.productArchive(randomId()), null);

      expectProblem(response, 404, 'Product.NotFound');
    });
  });

  group('P6 POST /api/products/{id}/units', () {
    test('AddUnit_ContractExample_201UnitDto', () async {
      final id = seeded('كونجستال').id;
      final response = await post(
        ApiPaths.productUnits(id),
        fixture('unit_request')..['name'] = 'كرتونة',
      );

      expect(response.statusCode, HttpStatus.created);
      expectSameShape(json(response), fixture('unit_dto'));
      final unitId = json(response)['id']! as String;
      expect(
        response.headers.value('location'),
        ApiPaths.productUnit(id, unitId),
      );
      expect(json(response)['factor'], '3.000000');
    });

    test('AddUnit_DuplicateNameNormalized_409', () async {
      final response = await post(
        ApiPaths.productUnits(panadol().id),
        fixture('unit_request')..['name'] = ' علبة ',
      );

      expectProblem(response, 409, 'ProductUnit.DuplicateName');
    });

    test('AddUnit_BarcodeOfAnotherProductsUnit_409', () async {
      final response = await post(
        ApiPaths.productUnits(seeded('كونجستال').id),
        fixture('unit_request')
          ..['name'] = 'كرتونة'
          ..['barcode'] = FakeProductSeed.boxBarcode,
      );

      expectProblem(response, 409, 'ProductUnit.DuplicateBarcode');
    });

    test('AddUnit_ZeroFactor_400NotPositive', () async {
      final response = await post(
        ApiPaths.productUnits(panadol().id),
        fixture('unit_request')
          ..['name'] = 'كرتونة'
          ..['factor'] = '0',
      );

      expectProblem(response, 400, 'Precision.NotPositive');
    });

    test('AddUnit_BlankName_400NameRequired', () async {
      final response = await post(
        ApiPaths.productUnits(panadol().id),
        fixture('unit_request')..['name'] = '  ',
      );

      expectProblem(response, 400, 'ProductUnit.NameRequired');
    });

    test('AddUnit_ArchivedProduct_409', () async {
      final response = await post(
        ApiPaths.productUnits(seeded('فيفادول').id),
        fixture('unit_request'),
      );

      expectProblem(response, 409, 'Product.Archived');
    });

    test('AddUnit_UnknownProduct_404', () async {
      final response = await post(
        ApiPaths.productUnits(randomId()),
        fixture('unit_request'),
      );

      expectProblem(response, 404, 'Product.NotFound');
    });
  });

  group('P7 PUT /api/products/{id}/units/{unitId}', () {
    test('UpdateUnit_Valid_200', () async {
      final product = panadol();
      final box = product.units.last;

      final response = await put(ApiPaths.productUnit(product.id, box.id), {
        'name': 'علبة كبيرة',
        'factor': '6',
        'sellPrice': '80.00',
        'barcode': FakeProductSeed.boxBarcode,
      });

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('unit_dto'));
      expect(json(response)['factor'], '6.000000');
    });

    test('UpdateUnit_BaseFactorChanged_400BaseUnitFactorFixed', () async {
      final product = panadol();

      final response = await put(
        ApiPaths.productUnit(product.id, product.baseUnit.id),
        {'name': 'شريط', 'factor': '2', 'sellPrice': '15.00', 'barcode': null},
      );

      expectProblem(response, 400, 'ProductUnit.BaseUnitFactorFixed');
    });

    test('UpdateUnit_UnknownUnit_404ProductUnitNotFound', () async {
      final response = await put(
        ApiPaths.productUnit(panadol().id, randomId()),
        fixture('unit_request'),
      );

      expectProblem(response, 404, 'ProductUnit.NotFound');
    });
  });

  group('P8 DELETE /api/products/{id}/units/{unitId}', () {
    test('DeleteUnit_Unused_204', () async {
      final product = seeded('كونجستال');

      final response = await delete(
        ApiPaths.productUnit(product.id, product.units.last.id),
      );

      expect(response.statusCode, HttpStatus.noContent);
      expect(product.units, hasLength(1));
    });

    test('DeleteUnit_Base_400BaseUnitCannotBeRemoved', () async {
      final product = panadol();

      final response = await delete(
        ApiPaths.productUnit(product.id, product.baseUnit.id),
      );

      expectProblem(response, 400, 'ProductUnit.BaseUnitCannotBeRemoved');
    });

    test('DeleteUnit_InUse_409', () async {
      final product = panadol();

      final response = await delete(
        ApiPaths.productUnit(product.id, product.units.last.id),
      );

      expectProblem(response, 409, 'ProductUnit.InUse');
    });

    test('DeleteUnit_UnknownUnit_404', () async {
      final response = await delete(
        ApiPaths.productUnit(panadol().id, randomId()),
      );

      expectProblem(response, 404, 'ProductUnit.NotFound');
    });
  });

  group('P9 POST /api/products/{id}/adjustments', () {
    test('Adjust_ContractExample_201ManualAdjustment', () async {
      final response = await post(
        ApiPaths.productAdjustments(panadol().id),
        fixture('adjustment_request'),
      );

      expect(response.statusCode, HttpStatus.created);
      expectSameShape(json(response), fixture('stock_movement'));
      expect(json(response)['reason'], 'ManualAdjustment');
      expect(json(response)['balanceAfter'], '22.000');
      expect(panadol().quantity, Decimal.fromInt(22));
    });

    test('Adjust_InAUnit_ConvertedToBase', () async {
      final product = panadol();

      final response = await post(ApiPaths.productAdjustments(product.id), {
        'quantityChange': '1',
        'unitId': product.units.last.id,
        'note': 'علبة زيادة',
      });

      expect(json(response)['quantityChange'], '3.000');
    });

    test('Adjust_ArchivedProduct_StillAllowed', () async {
      final response = await post(
        ApiPaths.productAdjustments(seeded('فيفادول').id),
        fixture('adjustment_request'),
      );

      expect(response.statusCode, HttpStatus.created);
    });

    test('Adjust_Errors_ZeroNoteUnitStaff', () async {
      final id = panadol().id;
      expectProblem(
        await post(ApiPaths.productAdjustments(id), {
          'quantityChange': '0.000',
          'note': 'x',
        }),
        400,
        'Stock.ZeroChange',
      );
      expectProblem(
        await post(ApiPaths.productAdjustments(id), {
          'quantityChange': '1',
          'note': '  ',
        }),
        400,
        'Stock.NoteRequired',
      );
      expectProblem(
        await post(ApiPaths.productAdjustments(id), {
          'quantityChange': '1.0001',
          'note': 'x',
        }),
        400,
        'Precision.TooManyDecimals',
      );
      expectProblem(
        await post(ApiPaths.productAdjustments(id), {
          'quantityChange': '1',
          'unitId': randomId(),
          'note': 'x',
        }),
        404,
        'ProductUnit.NotFound',
      );
      expectProblem(
        await post(
          ApiPaths.productAdjustments(id),
          fixture('adjustment_request'),
          token: staff,
        ),
        403,
        'Auth.Forbidden',
      );
      expectProblem(
        await post(
          ApiPaths.productAdjustments(randomId()),
          fixture('adjustment_request'),
        ),
        404,
        'Product.NotFound',
      );
    });
  });

  group('P10 POST /api/products/{id}/stock-counts', () {
    test('Count_Different_200ChangedWithStockCountMovement', () async {
      final response = await post(
        ApiPaths.productStockCounts(panadol().id),
        fixture('stock_count_request'),
      );

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('stock_count_response'));
      expect(json(response)['changed'], isTrue);
      expect(json(response)['quantity'], '26.000');
      final movement = json(response)['movement']! as Map<String, Object?>;
      expect(movement['reason'], 'StockCount');
      expect(movement['quantityChange'], '2.000');
    });

    test('Count_Matches_200UnchangedNoMovement', () async {
      final before = state.movements.length;

      final response = await post(ApiPaths.productStockCounts(panadol().id), {
        'countedQuantity': '24',
        'unitId': null,
      });

      expect(json(response), {
        'changed': false,
        'quantity': '24.000',
        'movement': null,
      });
      expect(state.movements, hasLength(before));
    });

    test('Count_Errors_NegativeStaffUnknown', () async {
      final id = panadol().id;
      expectProblem(
        await post(ApiPaths.productStockCounts(id), {'countedQuantity': '-1'}),
        400,
        'Precision.Negative',
      );
      expectProblem(
        await post(
          ApiPaths.productStockCounts(id),
          fixture('stock_count_request'),
          token: staff,
        ),
        403,
        'Auth.Forbidden',
      );
      expectProblem(
        await post(
          ApiPaths.productStockCounts(randomId()),
          fixture('stock_count_request'),
        ),
        404,
        'Product.NotFound',
      );
    });
  });

  group('P11 GET /api/products/{id}/movements', () {
    test('Movements_NewestFirst_200Paged', () async {
      final response = await get(ApiPaths.productMovements(panadol().id));

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('movement_page'));
      final rows = items(response);
      expect(rows.map((m) => m['reason']), [
        'Sale',
        'InvoiceReceipt',
        'StockCount',
      ]);
      expect(rows.first['balanceAfter'], '24.000');
      expect(rows.first['saleId'], isNotNull);
    });

    test('Movements_Errors_PageSizeAndUnknown', () async {
      expectProblem(
        await get(
          ApiPaths.productMovements(panadol().id),
          query: {'pageSize': 0},
        ),
        400,
        'Validation.Failed',
      );
      expectProblem(
        await get(ApiPaths.productMovements(randomId())),
        404,
        'Product.NotFound',
      );
    });
  });

  group('P12 GET /api/products/lookup', () {
    test('Lookup_ProductBarcode_BaseUnit', () async {
      final response = await get(
        ApiPaths.productLookup,
        query: {'barcode': FakeProductSeed.panadolBarcode},
      );

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('product_lookup_response'));
      final unit = json(response)['unit']! as Map<String, Object?>;
      expect(unit['isBase'], isTrue);
    });

    test('Lookup_UnitBarcode_ThatUnit', () async {
      final response = await get(
        ApiPaths.productLookup,
        query: {'barcode': FakeProductSeed.boxBarcode},
      );

      final unit = json(response)['unit']! as Map<String, Object?>;
      expect(unit['name'], 'علبة');
    });

    test('Lookup_Errors_MissingAndUnknownAndArchived', () async {
      expectProblem(
        await get(ApiPaths.productLookup),
        400,
        'Validation.Failed',
      );
      expectProblem(
        await get(ApiPaths.productLookup, query: {'barcode': '000'}),
        404,
        'Product.NotFound',
      );
      panadol().isArchived = true;
      expectProblem(
        await get(
          ApiPaths.productLookup,
          query: {'barcode': FakeProductSeed.panadolBarcode},
        ),
        404,
        'Product.NotFound',
      );
    });
  });

  group('ProductsRemoteDataSource over the fake backend', () {
    late ProductsRepositoryImpl repository;

    setUp(() {
      final client = rawDio(adapter)
        ..options.headers[HttpHeaderNames.authorization] =
            '${HttpHeaderNames.bearerPrefix}$owner';
      repository = ProductsRepositoryImpl(ProductsRemoteDataSource(client));
    });

    test('Repository_ParsesEveryResponse', () async {
      final list = await repository.getProducts(
        const ProductQuery(lowStock: true),
        page: 1,
        pageSize: 100,
      );
      expect(list, isA<Ok<Object?, Failure>>());

      final detail = await repository.getProduct(panadol().id);
      final movements = await repository.getMovements(
        panadol().id,
        page: 1,
        pageSize: 20,
      );
      final lookup = await repository.lookupBarcode(FakeProductSeed.boxBarcode);

      expect(okValue(detail), isNotNull);
      final page = okValue(movements);
      expect(
        page.items.first.reason,
        StockMovementReason.sale,
        reason: 'newest first',
      );
      expect(okValue(lookup), isNotNull);
    });

    test('Repository_MapsProblemsToFailures', () async {
      final result = await repository.getProduct(randomId());

      expect((result as Err<Object?, Failure>).failure, isA<NotFoundFailure>());
    });
  });
}
