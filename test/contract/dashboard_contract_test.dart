import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_invoice_records.dart';
import 'package:stockly/core/fake_backend/seed/fake_invoice_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_product_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:stockly/features/dashboard/data/repositories/dashboard_repository_impl.dart';

import '../helpers/fake_app.dart';
import '../helpers/products_doubles.dart' show okValue;
import '../helpers/test_doubles.dart';
import 'json_shape.dart';

/// Contract D1–D2 (v1.4 §8) against the fake backend, computed from the
/// fake state: counts, today's sales by the Cairo day, the invoices
/// awaiting review and the expiring confirmed lines with stock.
const int _dateLength = 10;

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

  Map<String, Object?> json(Response<Object?> response) =>
      response.data! as Map<String, Object?>;

  Future<Map<String, Object?>> summary() async {
    final response = await dio.get<Object?>(
      ApiPaths.dashboardSummary,
      options: auth(),
    );
    expect(response.statusCode, HttpStatus.ok, reason: '${response.data}');
    return json(response);
  }

  Future<Response<Object?>> expiring([Map<String, Object?>? query]) =>
      dio.get<Object?>(
        ApiPaths.dashboardExpiringSoon,
        queryParameters: query,
        options: auth(),
      );

  Future<void> sell({String? unitPrice, String quantity = '1.000'}) async {
    final product = state.products.firstWhere(
      (p) => p.barcode == FakeProductSeed.panadolBarcode,
    );
    serial++;
    final suffix = serial.toRadixString(16).padLeft(12, '0');
    final response = await dio.post<Object?>(
      ApiPaths.sales,
      data: {
        'clientRequestId': '0192f0a0-6c1e-7b3a-9d2e-$suffix',
        'note': null,
        'items': [
          {
            'productId': product.id,
            'productUnitId': product.baseUnit.id,
            'quantity': quantity,
            'unitPrice': unitPrice,
          },
        ],
      },
      options: auth(),
    );
    expect(response.statusCode, HttpStatus.created);
  }

  /// `yyyy-MM-dd` [offset] days from the fake clock (Cairo and UTC agree
  /// on the day at 07:00 UTC).
  String day(int offset) => clock
      .now()
      .add(Duration(days: offset))
      .toIso8601String()
      .substring(0, _dateLength);

  List<Map<String, Object?>> itemsOf(Response<Object?> response) =>
      (json(response)['items']! as List<Object?>).cast<Map<String, Object?>>();

  /// Adds a received line of [productName] to the seeded confirmed invoice.
  void addLine({
    required String id,
    required String productName,
    required String expiryDate,
    int quantity = 12,
  }) {
    final product = state.products.firstWhere((p) => p.name == productName);
    state.invoices
        .firstWhere((i) => i.id == FakeInvoiceSeed.confirmedId)
        .items
        .add(
          FakeInvoiceItem(
            id: id,
            lineNo: 10,
            rawName: productName,
            productId: product.id,
            productUnitId: product.baseUnit.id,
            quantity: Decimal.fromInt(quantity),
            unitPrice: Decimal.one,
            lineTotal: Decimal.fromInt(quantity),
            expiryDate: expiryDate,
            batchNo: null,
            matchConfidence: null,
            newProduct: null,
          ),
        );
  }

  group('D1 GET /api/dashboard/summary', () {
    test('ShapeAndCountsFromTheState', () async {
      final body = await summary();

      expectSameShape(body, fixture('dashboard_summary'));
      final active = state.products.where((p) => !p.isArchived).toList();
      expect(body['productCount'], active.length);
      expect(body['lowStockCount'], active.where((p) => p.isLowStock).length);
      expect(
        body['negativeStockCount'],
        active.where((p) => p.quantity < Decimal.zero).length,
      );
      expect(body['negativeStockCount'], greaterThan(0));
      expect(body['expiringSoonCount'], 1);
      expect(body['invoicesAwaitingReview'], 2);
      expect(body['todaySales'], {
        'count': 0,
        'total': '0.00',
        'overriddenSalesCount': 0,
      });
      expect(body['generatedAt'], clock.now().toIso8601String());
    });

    test('TodaySales_ByTheCairoDay', () async {
      await sell();
      await sell(unitPrice: '10.00', quantity: '2.000');

      var body = await summary();
      expect(body['todaySales'], {
        'count': 2,
        'total': '35.00',
        'overriddenSalesCount': 1,
      });

      clock.advance(const Duration(days: 1));
      owner = (await loginOn(adapter)).accessToken;
      body = await summary();
      expect((body['todaySales']! as Map)['count'], 0);
    });

    test('ProcessingInvoiceRead_CountsAsAwaitingReview', () async {
      clock.advance(const Duration(seconds: 7));

      final body = await summary();

      expect(body['invoicesAwaitingReview'], 3);
      expect(
        state.invoices
            .firstWhere((i) => i.id == FakeInvoiceSeed.processingId)
            .status,
        FakeInvoiceStatuses.needsReview,
      );
    });

    test('NoToken_401', () async {
      final response = await dio.get<Object?>(
        ApiPaths.dashboardSummary,
        options: auth(token: 'nope'),
      );
      expect(response.statusCode, HttpStatus.unauthorized);
      expect(json(response)['code'], ApiErrorCode.authUnauthenticated.wire);
    });
  });

  group('D2 GET /api/dashboard/expiring-soon', () {
    test('DefaultSixtyDays_SoonestFirst', () async {
      final response = await expiring();

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(json(response), fixture('expiring_page'));
      final items = (json(response)['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items, hasLength(1));
      expect(items.single['invoiceId'], FakeInvoiceSeed.confirmedId);
      expect(items.single['batchNo'], 'BR-40');
      expect(items.single['lineQuantity'], '4.000');
    });

    test('NinetyDays_BothLinesInDateOrder', () async {
      final response = await expiring({ApiQuery.days: 90});

      final items = (json(response)['items']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items, hasLength(2));
      expect(
        (items.first['expiryDate']! as String).compareTo(
          items.last['expiryDate']! as String,
        ),
        lessThan(0),
      );
    });

    test('AlreadyExpiredLineWithStock_Included', () async {
      addLine(
        id: '0192f0a0-6c1e-7b3a-9d2e-e1000000ff01',
        productName: 'كونجستال',
        expiryDate: day(-3),
      );

      final items = itemsOf(await expiring());
      final body = await summary();

      expect(items.map((i) => i['expiryDate']), [day(-3), day(20)]);
      expect(items.first['productName'], 'كونجستال');
      expect(items.first['lineQuantity'], '12.000');
      expect(body['expiringSoonCount'], 2);
    });

    test('Order_ExpiryThenProductNameThenLineId', () async {
      final when = day(10);
      addLine(
        id: '0192f0a0-6c1e-7b3a-9d2e-e1000000ff03',
        productName: 'كونجستال',
        expiryDate: when,
        quantity: 3,
      );
      addLine(
        id: '0192f0a0-6c1e-7b3a-9d2e-e1000000ff02',
        productName: 'كونجستال',
        expiryDate: when,
        quantity: 2,
      );
      addLine(
        id: '0192f0a0-6c1e-7b3a-9d2e-e1000000ff04',
        productName: 'بنادول اكسترا',
        expiryDate: when,
      );
      addLine(
        id: '0192f0a0-6c1e-7b3a-9d2e-e1000000ff05',
        productName: 'بنادول اكسترا',
        expiryDate: day(-1),
      );

      final items = itemsOf(await expiring());

      expect(
        items.map(
          (i) => (i['expiryDate'], i['productName'], i['lineQuantity']),
        ),
        [
          (day(-1), 'بنادول اكسترا', '12.000'),
          (when, 'بنادول اكسترا', '12.000'),
          (when, 'كونجستال', '2.000'),
          (when, 'كونجستال', '3.000'),
          (day(20), 'بروفين 400', '4.000'),
        ],
      );
    });

    test('ArchivedProduct_LeftOut', () async {
      final archived = state.products.firstWhere((p) => p.isArchived);
      state.recordMovement(
        archived,
        id: '0192f0a0-6c1e-7b3a-9d2e-c0000000fffe',
        change: Decimal.fromInt(5),
        reason: 'StockCount',
        userId: state.users.first.id,
        at: clock.now(),
      );
      addLine(
        id: '0192f0a0-6c1e-7b3a-9d2e-e1000000ff06',
        productName: archived.name,
        expiryDate: day(-2),
      );

      expect(itemsOf(await expiring()), hasLength(1));
    });

    test('NoStock_LeftOut', () async {
      final item = state.invoices
          .firstWhere((i) => i.id == FakeInvoiceSeed.confirmedId)
          .items
          .first;
      final product = state.products.firstWhere((p) => p.id == item.productId);
      state.recordMovement(
        product,
        id: '0192f0a0-6c1e-7b3a-9d2e-c0000000ffff',
        change: -product.quantity,
        reason: 'StockCount',
        userId: state.users.first.id,
        at: clock.now(),
      );

      final response = await expiring();

      expect(json(response)['totalCount'], 0);
    });

    test('BadDays_400', () async {
      for (final days in [0, 366, 'x']) {
        final response = await expiring({ApiQuery.days: days});
        expect(response.statusCode, HttpStatus.badRequest, reason: '$days');
        expect(json(response)['code'], ApiErrorCode.validationFailed.wire);
      }
    });
  });

  test('Repository_ParsesBothResponses', () async {
    final client = rawDio(adapter)
      ..options.headers[HttpHeaderNames.authorization] =
          '${HttpHeaderNames.bearerPrefix}$owner';
    final repository = DashboardRepositoryImpl(
      DashboardRemoteDataSource(client),
    );

    final summary = okValue(await repository.getSummary());
    final page = okValue(
      await repository.getExpiringSoon(days: 90, page: 1, pageSize: 20),
    );

    expect(summary.todaySales.total, Money.zero);
    expect(summary.generatedAt, clock.now());
    expect(page.items, hasLength(2));
    expect(page.items.first.lineQuantity, Quantity.fromApi('4.000'));
  });
}
