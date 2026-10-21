import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/seed/fake_product_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/features/products/data/datasources/products_remote_data_source.dart';
import 'package:stockly/features/products/data/repositories/products_repository_impl.dart';
import 'package:stockly/features/sales/data/datasources/pending_sales_local_data_source.dart';
import 'package:stockly/features/sales/data/datasources/sales_remote_data_source.dart';
import 'package:stockly/features/sales/data/models/sale_mapper.dart';
import 'package:stockly/features/sales/data/repositories/sales_repository_impl.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';

import '../helpers/fake_app.dart';
import '../helpers/products_doubles.dart' show errOf, okValue;
import '../helpers/test_doubles.dart';
import 'json_shape.dart';

/// Contract S1–S3 (v1.4 §7) and P12 against the fake backend: status
/// codes, `clientRequestId` idempotency, the validation order, stock taken
/// out through movements, price overrides, negative-stock warnings, paging
/// and the JSON shapes of the contract fixtures.
void main() {
  late FakeClock clock;
  late FakeBackendState state;
  late FakeBackendAdapter adapter;
  late Dio dio;
  late String owner;
  var serial = 0;

  setUp(() async {
    clock = FakeClock();
    state = FakeSeed.pharmacy(clock.now());
    adapter = fakeBackend(clock: clock, state: state);
    dio = rawDio(adapter)..options.validateStatus = ((_) => true);
    owner = (await loginOn(adapter)).accessToken;
  });

  Options auth({String? token}) => Options(
    headers: {
      HttpHeaderNames.acceptLanguage: 'en',
      HttpHeaderNames.authorization:
          '${HttpHeaderNames.bearerPrefix}${token ?? owner}',
    },
  );

  String newId() {
    serial++;
    final suffix = serial.toRadixString(16).padLeft(12, '0');
    return '0192f0a0-6c1e-7b3a-9d2e-$suffix';
  }

  Map<String, Object?> json(Response<Object?> response) =>
      response.data! as Map<String, Object?>;

  void expectProblem(Response<Object?> response, int status, String code) {
    expect(response.statusCode, status, reason: '${response.data}');
    expect(
      response.headers.value(Headers.contentTypeHeader),
      startsWith('application/problem+json'),
    );
    expect(json(response)['code'], code);
  }

  FakeProduct panadol() => state.products.firstWhere(
    (p) => p.barcode == FakeProductSeed.panadolBarcode,
  );

  Map<String, Object?> item(
    FakeProduct product, {
    FakeUnit? unit,
    Object? quantity = '2.000',
    Object? unitPrice,
  }) => {
    'productId': product.id,
    'productUnitId': (unit ?? product.baseUnit).id,
    'quantity': quantity,
    'unitPrice': unitPrice,
  };

  Future<Response<Object?>> post(
    List<Object?> items, {
    String? clientRequestId,
    Object? note,
    String? token,
  }) => dio.post<Object?>(
    ApiPaths.sales,
    data: {
      'clientRequestId': clientRequestId ?? newId(),
      'note': note,
      'items': items,
    },
    options: auth(token: token),
  );

  group('S1 POST /api/sales', () {
    test('New_201WithLocationAndStockTakenOut', () async {
      final product = panadol();
      final before = product.quantity;

      final response = await post([
        item(product, unit: product.units.last, quantity: '1.000'),
        item(product, unitPrice: '14.00'),
      ], note: ' دفع كاش ');

      expect(
        response.statusCode,
        HttpStatus.created,
        reason: '${response.data}',
      );
      final body = json(response);
      expectSameShape(body, fixture('sale'), enums: saleEnums);
      expect(
        response.headers.value('location'),
        '${ApiPaths.sales}/${body['id']}',
      );
      // One box of 3 strips and 2 strips.
      expect(product.quantity, before - Decimal.fromInt(5));
      final items = (body['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items.first['listUnitPrice'], '40.00');
      expect(items.first['unitPrice'], '40.00');
      expect(items.first['priceOverridden'], isFalse);
      expect(items.first['lineTotal'], '40.00');
      expect(items.last['unitPrice'], '14.00');
      expect(items.last['listUnitPrice'], '15.00');
      expect(items.last['priceOverridden'], isTrue);
      expect(items.last['balanceAfter'], product.quantity.toStringAsFixed(3));
      expect(body['priceOverridden'], isTrue);
      expect(body['totalAmount'], '68.00');
      expect(body['note'], 'دفع كاش');
      expect(body['warnings'], isEmpty);
      final movements = state.movements
          .where((m) => m.saleId == body['id'])
          .toList();
      expect(movements.map((m) => m.quantityChange), [
        Decimal.fromInt(-3),
        Decimal.fromInt(-2),
      ]);
      expect(
        movements.every((m) => m.reason == FakeMovementReasons.sale),
        isTrue,
      );
    });

    test('Repeat_200TheSameSaleAndNoNewMovements', () async {
      final id = newId();
      final first = await post([item(panadol())], clientRequestId: id);
      final movements = state.movements.length;

      final repeat = await post([
        item(panadol(), quantity: '9.000'),
      ], clientRequestId: id.toUpperCase());

      expect(repeat.statusCode, HttpStatus.ok);
      expect(json(repeat), json(first));
      expect(state.movements, hasLength(movements));
    });

    test('BelowZero_SaleRecordedWithANegativeBalanceWarning', () async {
      final product = panadol();
      final quantity = (product.quantity + Decimal.one).toStringAsFixed(3);

      final response = await post([item(product, quantity: quantity)]);

      expect(response.statusCode, HttpStatus.created);
      expect(product.quantity, Decimal.fromInt(-1));
      expect(json(response)['warnings'], [
        {'code': 'Stock.NegativeBalance', 'productId': product.id},
      ]);
    });

    test('Shape_400ValidationFailed', () async {
      final product = panadol();
      for (final (items, field) in [
        (<Object?>[], 'items'),
        ([item(product, quantity: '0')], 'items[0].quantity'),
        ([item(product, quantity: 2)], 'items[0].quantity'),
        ([item(product, unitPrice: 14)], 'items[0].unitPrice'),
        (
          [
            {...item(product), 'productId': null},
          ],
          'items[0].productId',
        ),
        ([for (var i = 0; i < 101; i++) item(product)], 'items'),
      ]) {
        final response = await post(items);
        expectProblem(
          response,
          HttpStatus.badRequest,
          ApiErrorCode.validationFailed.wire,
        );
        expect(
          (json(response)['errors']! as Map).keys,
          contains(field),
          reason: field,
        );
      }
      final noId = await dio.post<Object?>(
        ApiPaths.sales,
        data: {
          'items': [item(product)],
        },
        options: auth(),
      );
      expect((json(noId)['errors']! as Map).keys, contains('clientRequestId'));
    });

    test('Precision_400', () async {
      final product = panadol();
      for (final (line, code) in [
        (
          item(product, quantity: '1.0001'),
          ApiErrorCode.precisionTooManyDecimals,
        ),
        (
          item(product, unitPrice: '1.001'),
          ApiErrorCode.precisionTooManyDecimals,
        ),
        (item(product, unitPrice: '-1.00'), ApiErrorCode.precisionNegative),
        (
          item(product, unitPrice: '99999999999999999.00'),
          ApiErrorCode.precisionOutOfRange,
        ),
      ]) {
        expectProblem(await post([line]), HttpStatus.badRequest, code.wire);
      }
    });

    test('Lines_InRequestOrder_NothingWrittenOnFailure', () async {
      final product = panadol();
      final other = state.products.firstWhere(
        (p) => p.id != product.id && !p.isArchived,
      );
      final archived = state.products.firstWhere((p) => p.isArchived);
      final movements = state.movements.length;
      for (final (line, status, code) in [
        (
          {
            ...item(product),
            'productId': '0192f0a0-6c1e-7b3a-9d2e-a0000000ffff',
          },
          HttpStatus.notFound,
          ApiErrorCode.productNotFound,
        ),
        (
          {...item(product), 'productUnitId': other.baseUnit.id},
          HttpStatus.badRequest,
          ApiErrorCode.saleUnitNotOfProduct,
        ),
        (
          {
            ...item(product),
            'productUnitId': '0192f0a0-6c1e-7b3a-9d2e-b0000000ffff',
          },
          HttpStatus.notFound,
          ApiErrorCode.productUnitNotFound,
        ),
        (
          item(archived),
          HttpStatus.badRequest,
          ApiErrorCode.saleArchivedProduct,
        ),
      ]) {
        expectProblem(await post([item(product), line]), status, code.wire);
      }
      expect(state.movements, hasLength(movements));
    });

    test('NoToken_401', () async {
      expectProblem(
        await post([item(panadol())], token: 'nope'),
        HttpStatus.unauthorized,
        ApiErrorCode.authUnauthenticated.wire,
      );
    });
  });

  group('S2 GET /api/sales and S3 GET /api/sales/{id}', () {
    test('List_NewestFirstWithTheRange', () async {
      final first = json(await post([item(panadol())]));
      clock.advance(const Duration(minutes: 10));
      final second = json(await post([item(panadol())]));

      final all = await dio.get<Object?>(ApiPaths.sales, options: auth());
      expectSameShape(json(all), fixture('sale_list_page'));
      expect(
        (json(all)['items']! as List<Object?>).map((i) => (i! as Map)['id']),
        [second['id'], first['id']],
      );

      final recent = await dio.get<Object?>(
        ApiPaths.sales,
        queryParameters: {
          ApiQuery.from: clock
              .now()
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        },
        options: auth(),
      );
      expect(json(recent)['totalCount'], 1);

      final bad = await dio.get<Object?>(
        ApiPaths.sales,
        queryParameters: {ApiQuery.pageSize: 101},
        options: auth(),
      );
      expectProblem(
        bad,
        HttpStatus.badRequest,
        ApiErrorCode.validationFailed.wire,
      );
    });

    test('Detail_AndNotFound', () async {
      final created = json(await post([item(panadol())]));

      final detail = await dio.get<Object?>(
        ApiPaths.sale(created['id']! as String),
        options: auth(),
      );
      expect(json(detail), created);
      expectProblem(
        await dio.get<Object?>(
          ApiPaths.sale('0192f0a0-6c1e-7b3a-9d2e-5a1e0000ffff'),
          options: auth(),
        ),
        HttpStatus.notFound,
        ApiErrorCode.saleNotFound.wire,
      );
    });
  });

  group('Sales data layer over the fake backend', () {
    late AppDatabase database;
    late SalesRepositoryImpl repository;
    late Dio client;

    setUp(() {
      database = inMemoryDatabase();
      addTearDown(database.close);
      client = rawDio(adapter)
        ..options.headers[HttpHeaderNames.authorization] =
            '${HttpHeaderNames.bearerPrefix}$owner';
      repository = SalesRepositoryImpl(
        remote: SalesRemoteDataSource(client),
        local: PendingSalesLocalDataSource(database.pendingSalesDao, clock),
      );
    });

    SaleRequest request(String id, {Money? price}) => SaleRequest(
      clientRequestId: id,
      note: null,
      items: [
        SaleRequestItem(
          productId: panadol().id,
          productUnitId: panadol().baseUnit.id,
          quantity: Quantity.fromApi('2.000'),
          unitPrice: price,
        ),
      ],
    );

    test('RequestBody_MatchesTheContractFixture', () {
      final body = request(newId()).toDto().toJson();

      expectSameShape(body, fixture('create_sale_request'));
      final line = (body['items']! as List<Object?>).single! as Map;
      expect(line['quantity'], '2.000');
      expect(line.containsKey('unitPrice'), isTrue);
      expect(line['unitPrice'], isNull);
    });

    test('Submit_CreatedThenAlreadyRecorded_NoRowLeft', () async {
      final id = newId();
      final shopId = state.shops.single.id;
      final userId = state.users.first.id;

      final created = okValue(
        await repository.submit(
          request(id, price: Money.fromApi('14.00')),
          shopId: shopId,
          userId: userId,
        ),
      );
      final repeat = okValue(
        await repository.submit(request(id), shopId: shopId, userId: userId),
      );

      expect(created, isA<SaleCreated>());
      expect(repeat, isA<SaleAlreadyRecorded>());
      expect(repeat.sale.id, created.sale.id);
      expect(created.sale.items.single.priceOverridden, isTrue);
      expect(created.sale.items.single.unitPrice, Money.fromApi('14.00'));
      expect(await repository.pendingSale(shopId), isNull);
    });

    test('Submit_Offline_RowKeptAndRetriedWithTheSameBody', () async {
      final id = newId();
      final shopId = state.shops.single.id;
      adapter.controls.offline = true;

      final failure = errOf(
        await repository.submit(
          request(id, price: Money.fromApi('13.50')),
          shopId: shopId,
          userId: state.users.first.id,
        ),
      );
      expect(failure, const NetworkFailure());
      final pending = await repository.pendingSale(shopId);
      expect(pending?.request, request(id, price: Money.fromApi('13.50')));
      expect(pending?.attemptCount, 1);

      adapter.controls.offline = false;
      // A different cart with the same id: the stored body is what is sent.
      final submission = okValue(
        await repository.submit(
          request(id),
          shopId: shopId,
          userId: state.users.first.id,
        ),
      );
      expect(submission, isA<SaleCreated>());
      expect(submission.sale.items.single.unitPrice, Money.fromApi('13.50'));
      expect(await repository.pendingSale(shopId), isNull);
    });

    test('Submit_DefiniteFailure_RowRemoved', () async {
      final shopId = state.shops.single.id;
      final archived = state.products.firstWhere((p) => p.isArchived);

      final failure = errOf(
        await repository.submit(
          SaleRequest(
            clientRequestId: newId(),
            note: null,
            items: [
              SaleRequestItem(
                productId: archived.id,
                productUnitId: archived.baseUnit.id,
                quantity: Quantity.fromApi('1.000'),
                unitPrice: null,
              ),
            ],
          ),
          shopId: shopId,
          userId: state.users.first.id,
        ),
      );

      expect((failure as ApiFailure).code, ApiErrorCode.saleArchivedProduct);
      expect(await repository.pendingSale(shopId), isNull);
    });

    test('Submit_DefiniteFailureAfterAnUnknownOutcome_RowKept', () async {
      final id = newId();
      final shopId = state.shops.single.id;
      final userId = state.users.first.id;
      adapter.controls.offline = true;
      errOf(
        await repository.submit(request(id), shopId: shopId, userId: userId),
      );

      // The first attempt may have been recorded; a 401 on the retry is
      // decided before the server looks the id up, so it proves nothing.
      adapter.controls.offline = false;
      client.options.headers.remove(HttpHeaderNames.authorization);
      final failure = errOf(
        await repository.submit(request(id), shopId: shopId, userId: userId),
      );

      expect(failure, isA<SessionEndedFailure>());
      final pending = await repository.pendingSale(shopId);
      expect(pending?.request.clientRequestId, id);
      expect(pending?.attemptCount, 2);
    });

    test('ListAndDetail_ParseEveryResponse', () async {
      final shopId = state.shops.single.id;
      final product = panadol();
      final created = okValue(
        await repository.submit(
          SaleRequest(
            clientRequestId: newId(),
            note: 'x',
            items: [
              SaleRequestItem(
                productId: product.id,
                productUnitId: product.baseUnit.id,
                quantity: Quantity.fromApi(
                  (product.quantity + Decimal.one).toStringAsFixed(3),
                ),
                unitPrice: null,
              ),
            ],
          ),
          shopId: shopId,
          userId: state.users.first.id,
        ),
      ).sale;
      expect(created.warnings.single.code, SaleWarningCode.negativeBalance);

      final list = okValue(
        await repository.getSales(
          from: clock.now().subtract(const Duration(minutes: 1)),
          page: 1,
          pageSize: 20,
        ),
      );
      expect(list.items.single.id, created.id);
      final detail = okValue(await repository.getSale(created.id));
      expect(detail, created);
      expect(
        errOf(await repository.getSale('0192f0a0-6c1e-7b3a-9d2e-5a1e0000ffff')),
        isA<NotFoundFailure>(),
      );
    });

    test('P12_LookupByProductAndUnitBarcode', () async {
      final products = ProductsRepositoryImpl(ProductsRemoteDataSource(client));

      final byProduct = okValue(
        await products.lookupBarcode(FakeProductSeed.panadolBarcode),
      );
      final byUnit = okValue(
        await products.lookupBarcode(FakeProductSeed.boxBarcode),
      );

      expect(byProduct.unit.isBase, isTrue);
      expect(byUnit.unit.barcode, FakeProductSeed.boxBarcode);
      expect(byUnit.product.id, byProduct.product.id);
      final missing = errOf(await products.lookupBarcode('000000'));
      expect((missing as NotFoundFailure).code, ApiErrorCode.productNotFound);
    });
  });
}
