import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_invoice_records.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/handlers/fake_invoices_handler.dart';
import 'package:stockly/core/fake_backend/seed/fake_invoice_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/models/invoice_mapper.dart';
import 'package:stockly/features/invoices/data/repositories/invoices_repository_impl.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_warning.dart';
import 'package:stockly/features/invoices/domain/entities/new_product.dart';

import '../helpers/fake_app.dart';
import '../helpers/products_doubles.dart' show errOf, okValue;
import '../helpers/test_doubles.dart';
import 'json_shape.dart';

const String _jpegType = 'image/jpeg';

/// Contract I1–I4 (v1.4 §6) against the fake backend: status codes, error
/// codes, `Retry-After`, idempotency, the processing transition, decimal
/// scales and JSON shapes from the contract fixtures.
void main() {
  late FakeClock clock;
  late FakeBackendState state;
  late FakeBackendAdapter adapter;
  late Dio dio;
  late String owner;
  var serial = 0;

  FakeBackendAdapter backend({
    FakeBackendConfig config = const FakeBackendConfig(latency: Duration.zero),
  }) => fakeBackend(clock: clock, state: state, config: config);

  Future<void> start({
    FakeBackendConfig config = const FakeBackendConfig(latency: Duration.zero),
  }) async {
    clock = FakeClock();
    state = FakeSeed.pharmacy(clock.now());
    adapter = backend(config: config);
    dio = rawDio(adapter)..options.validateStatus = ((_) => true);
    owner = (await loginOn(adapter)).accessToken;
  }

  setUp(start);

  Options auth({String? token, String language = 'en'}) => Options(
    headers: {
      HttpHeaderNames.acceptLanguage: language,
      HttpHeaderNames.authorization:
          '${HttpHeaderNames.bearerPrefix}${token ?? owner}',
    },
  );

  String newId() {
    serial++;
    final suffix = serial.toRadixString(16).padLeft(12, '0');
    return '0192f0a0-6c1e-7b3a-9d2e-$suffix';
  }

  Future<Response<Object?>> scan({
    String? clientRequestId,
    bool withId = true,
    int bytes = 2048,
    String contentType = _jpegType,
    bool withImage = true,
    String? token,
  }) => dio.post<Object?>(
    ApiPaths.invoicesScan,
    data: FormData.fromMap({
      if (withImage)
        ApiForm.image: MultipartFile.fromBytes(
          Uint8List(bytes),
          filename: 'scan.jpg',
          contentType: DioMediaType.parse(contentType),
        ),
      if (withId) ApiForm.clientRequestId: clientRequestId ?? newId(),
    }),
    options: auth(token: token),
  );

  Future<Response<Object?>> get(String path, {Map<String, Object?>? query}) =>
      dio.get<Object?>(path, queryParameters: query, options: auth());

  Future<Response<Object?>> put(String path, Object? body, {String? token}) =>
      dio.put<Object?>(
        path,
        data: body,
        options: auth(token: token),
      );

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

  FakeProduct product(String name) =>
      state.products.firstWhere((p) => p.name == name);

  Map<String, Object?> line({
    int lineNo = 1,
    Object? productId,
    Object? unitId,
    Object? newProduct,
    Object? quantity = '10.000',
    Object? unitPrice = '36.00',
  }) => {
    'lineNo': lineNo,
    'rawName': 'بنادول اكسترا ٢٠ قرص',
    'productId': productId,
    'productUnitId': unitId,
    'newProduct': newProduct,
    'quantity': quantity,
    'unitPrice': unitPrice,
    'expiryDate': '2027-03-31',
    'batchNo': 'B12',
  };

  Map<String, Object?> panadolLine({int lineNo = 1}) {
    final panadol = product('بنادول اكسترا');
    return line(
      lineNo: lineNo,
      productId: panadol.id,
      unitId: panadol.units.last.id,
    );
  }

  Map<String, Object?> body(List<Map<String, Object?>> items) => {
    'supplierName': 'شركة الأدوية المتحدة',
    'invoiceNumber': 'INV-1043',
    'invoiceDate': '2026-10-10',
    'totalAmount': '360.00',
    'items': items,
  };

  String reviewItems() => ApiPaths.invoiceItems(FakeInvoiceSeed.needsReviewId);

  group('I1 POST /api/invoices/scan', () {
    test('NewScan_202ProcessingListItemWithLocation', () async {
      final response = await scan();

      expect(response.statusCode, HttpStatus.accepted);
      expectSameShape(
        json(response),
        fixture('invoice_list_item'),
        enums: invoiceEnums,
      );
      expect(json(response)['status'], 'Processing');
      expect(
        response.headers.value('location'),
        '${ApiPaths.invoices}/${json(response)['id']}',
      );
    });

    test('SameClientRequestId_200SameInvoice_NoQuotaUsed', () async {
      await start(
        config: const FakeBackendConfig(
          latency: Duration.zero,
          scanDailyQuota: 1,
        ),
      );
      final id = newId();
      final first = await scan(clientRequestId: id);

      final repeat = await scan(clientRequestId: id);

      expect(first.statusCode, HttpStatus.accepted);
      expect(repeat.statusCode, HttpStatus.ok);
      expect(json(repeat)['id'], json(first)['id']);
      expect(
        state.invoices.where((i) => i.clientRequestId == id),
        hasLength(1),
      );
    });

    test('MissingClientRequestId_400ValidationFailed', () async {
      final response = await scan(withId: false);

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
      expect(json(response)['errors'], contains('clientRequestId'));
    });

    test('MalformedClientRequestId_400ValidationFailed', () async {
      final response = await scan(clientRequestId: 'not-a-uuid');

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
    });

    test('NoImage_400ImageRequired', () async {
      final response = await scan(withImage: false);

      expectProblem(response, HttpStatus.badRequest, 'Invoice.ImageRequired');
    });

    test('Pdf_400UnsupportedImageType', () async {
      final response = await scan(contentType: 'application/pdf');

      expectProblem(
        response,
        HttpStatus.badRequest,
        'Invoice.UnsupportedImageType',
      );
    });

    test('PngAndWebp_Accepted', () async {
      expect((await scan(contentType: 'image/png')).statusCode, 202);
      expect((await scan(contentType: 'image/webp')).statusCode, 202);
    });

    test('Over8Mb_413ImageTooLarge', () async {
      final response = await scan(bytes: 8 * 1024 * 1024 + 1);

      expectProblem(
        response,
        HttpStatus.requestEntityTooLarge,
        'Invoice.ImageTooLarge',
      );
    });

    test('RateLimit_429RateLimitedWithRetryAfter', () async {
      await start(
        config: const FakeBackendConfig(
          latency: Duration.zero,
          scanRateLimit: 2,
        ),
      );
      await scan();
      clock.advance(const Duration(seconds: 20));
      await scan();

      final limited = await scan();

      expectProblem(limited, HttpStatus.tooManyRequests, 'Scan.RateLimited');
      expect(limited.headers.value('retry-after'), '40');
      clock.advance(const Duration(seconds: 40));
      expect((await scan()).statusCode, HttpStatus.accepted);
    });

    test('DailyQuota_429WithRetryAfterUntilCairoMidnight', () async {
      await start(
        config: const FakeBackendConfig(
          latency: Duration.zero,
          scanDailyQuota: 1,
        ),
      );
      await scan();

      final limited = await scan();

      expectProblem(
        limited,
        HttpStatus.tooManyRequests,
        'Scan.DailyQuotaExceeded',
      );
      // 2026-10-12 07:00Z is 10:00 in Cairo (summer time, UTC+3): midnight
      // is 14 hours away.
      expect(limited.headers.value('retry-after'), '${14 * 3600}');
    });

    test('QuotaSwitch_RejectsEveryNewScan', () async {
      adapter.controls.scanQuotaExhausted = true;

      final response = await scan();

      expectProblem(
        response,
        HttpStatus.tooManyRequests,
        'Scan.DailyQuotaExceeded',
      );
    });

    test('NoToken_401Unauthenticated', () async {
      final response = await scan(token: 'nope');

      expectProblem(response, HttpStatus.unauthorized, 'Auth.Unauthenticated');
    });

    test(
      'Processing_TurnsNeedsReviewOnTheFakeClock_MatchingProducts',
      () async {
        final id = json(await scan())['id']! as String;
        final path = ApiPaths.invoice(id);
        expect(json(await get(path))['status'], 'Processing');

        clock.advance(FakeBackendConfig.defaultProcessingDelay);
        final detail = json(await get(path));

        expect(detail['status'], 'NeedsReview');
        expectSameShape(detail, fixture('invoice_detail'), enums: invoiceEnums);
        final items = detail['items']! as List<Object?>;
        final first = items.first! as Map<String, Object?>;
        expect(first['productId'], product('بنادول اكسترا').id);
        expect(first['matchConfidence'], '0.92');
        final unmatched = items.last! as Map<String, Object?>;
        expect(unmatched['productId'], isNull);
        expect(detail['warnings'], ['TotalMismatch']);
      },
    );

    test('ThirdScan_Fails', () async {
      final ids = [
        for (var i = 0; i < 3; i++) json(await scan())['id']! as String,
      ];

      clock.advance(FakeBackendConfig.defaultProcessingDelay);
      final failed = json(await get(ApiPaths.invoice(ids.last)));

      expect(failed['status'], 'Failed');
      expect(failed['failureReason'], isNotEmpty);
      expect(failed['items'], isEmpty);
    });
  });

  group('I2 GET /api/invoices', () {
    test('NewestFirst_PagedShape', () async {
      final response = await get(
        ApiPaths.invoices,
        query: {ApiQuery.pageSize: 2},
      );

      expect(response.statusCode, HttpStatus.ok);
      expectSameShape(
        json(response),
        fixture('invoice_page'),
        enums: invoiceEnums,
      );
      final page = json(response);
      expect(page['totalCount'], state.invoices.length);
      final items = page['items']! as List<Object?>;
      expect(items, hasLength(2));
      expect((items.first! as Map)['id'], FakeInvoiceSeed.processingId);
    });

    test('StatusFilter_OnlyThatStatus', () async {
      final response = await get(
        ApiPaths.invoices,
        query: {ApiQuery.status: 'NeedsReview'},
      );

      final items = json(response)['items']! as List<Object?>;
      expect(items, hasLength(2));
      expect(items.map((i) => (i! as Map)['status']).toSet(), {'NeedsReview'});
    });

    test('UnknownStatus_400ValidationFailed', () async {
      final response = await get(
        ApiPaths.invoices,
        query: {ApiQuery.status: 'Lost'},
      );

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
    });

    test('PageSizeOver100_400ValidationFailed', () async {
      final response = await get(
        ApiPaths.invoices,
        query: {ApiQuery.pageSize: 101},
      );

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
    });
  });

  group('I3 GET /api/invoices/{id}', () {
    test('Seeded_EveryStatus_DetailShape', () async {
      for (final (id, status) in [
        (FakeInvoiceSeed.needsReviewId, 'NeedsReview'),
        (FakeInvoiceSeed.confirmedId, 'Confirmed'),
        (FakeInvoiceSeed.failedId, 'Failed'),
        (FakeInvoiceSeed.processingId, 'Processing'),
        (FakeInvoiceSeed.emptyId, 'NeedsReview'),
      ]) {
        final response = await get(ApiPaths.invoice(id));
        expect(response.statusCode, HttpStatus.ok);
        expectSameShape(
          json(response),
          fixture('invoice_detail'),
          enums: invoiceEnums,
        );
        expect(json(response)['status'], status);
      }
    });

    test('UnknownId_404InvoiceNotFound', () async {
      final response = await get(ApiPaths.invoice(newId()));

      expectProblem(response, HttpStatus.notFound, 'Invoice.NotFound');
    });

    test('AnotherShopsInvoice_404InvoiceNotFound', () async {
      final other = await rawDio(adapter).post<Object?>(
        ApiPaths.authRegister,
        data: fixture('register_request'),
        options: Options(extra: {RequestExtras.anonymous: true}),
      );
      final token =
          (other.data! as Map<String, Object?>)['accessToken']! as String;

      final response = await dio.get<Object?>(
        ApiPaths.invoice(FakeInvoiceSeed.needsReviewId),
        options: auth(token: token),
      );

      expectProblem(response, HttpStatus.notFound, 'Invoice.NotFound');
    });
  });

  group('I4 PUT /api/invoices/{id}/items', () {
    test('Save_200ReplacesLines_ServerLineTotalRoundedAwayFromZero', () async {
      final response = await put(reviewItems(), {
        ...body([
          line(
            productId: product('كونجستال').id,
            unitId: product('كونجستال').baseUnit.id,
            quantity: '0.333',
            unitPrice: '1.50',
          ),
        ]),
        'totalAmount': '0.50',
      });

      expect(response.statusCode, HttpStatus.ok, reason: '${response.data}');
      expectSameShape(
        json(response),
        fixture('invoice_detail'),
        enums: invoiceEnums,
      );
      final items = json(response)['items']! as List<Object?>;
      expect(items, hasLength(1));
      final first = items.single! as Map<String, Object?>;
      expect(first['lineTotal'], '0.50');
      expect(first['productName'], 'كونجستال');
      expect(json(response)['warnings'], isEmpty);
      expect(json(response)['computedTotal'], '0.50');
    });

    test('NewProductLine_Saved', () async {
      final response = await put(
        reviewItems(),
        body([
          line(
            newProduct: {
              'name': 'سيتال شراب',
              'baseUnitName': 'زجاجة',
              'sellPrice': '25.00',
            },
          ),
        ]),
      );

      expect(response.statusCode, HttpStatus.ok, reason: '${response.data}');
      final item =
          (json(response)['items']! as List<Object?>).single!
              as Map<String, Object?>;
      expect(item['newProduct'], {
        'name': 'سيتال شراب',
        'baseUnitName': 'زجاجة',
        'sellPrice': '25.00',
      });
      expect(item['productId'], isNull);
    });

    test('TotalOffByMoreThan2Percent_TotalMismatch', () async {
      final response = await put(reviewItems(), {
        ...body([panadolLine()]),
        'totalAmount': '400.00',
      });

      expect(json(response)['warnings'], ['TotalMismatch']);
    });

    test('LineWithoutProduct_400LineProductRequired', () async {
      final response = await put(reviewItems(), body([line()]));

      expectProblem(
        response,
        HttpStatus.badRequest,
        'Invoice.LineProductRequired',
      );
    });

    test('UnitOfAnotherProduct_400UnitNotOfProduct', () async {
      final response = await put(
        reviewItems(),
        body([
          line(
            productId: product('كونجستال').id,
            unitId: product('بنادول اكسترا').baseUnit.id,
          ),
        ]),
      );

      expectProblem(
        response,
        HttpStatus.badRequest,
        'Invoice.UnitNotOfProduct',
      );
    });

    test('UnknownProduct_404ProductNotFound', () async {
      final response = await put(
        reviewItems(),
        body([line(productId: newId(), unitId: newId())]),
      );

      expectProblem(response, HttpStatus.notFound, 'Product.NotFound');
    });

    test('UnknownUnit_404ProductUnitNotFound', () async {
      final response = await put(
        reviewItems(),
        body([line(productId: product('كونجستال').id, unitId: newId())]),
      );

      expectProblem(response, HttpStatus.notFound, 'ProductUnit.NotFound');
    });

    test('ConfirmedInvoice_409NotEditable', () async {
      final response = await put(
        ApiPaths.invoiceItems(FakeInvoiceSeed.confirmedId),
        body([panadolLine()]),
      );

      expectProblem(response, HttpStatus.conflict, 'Invoice.NotEditable');
    });

    test('UnknownInvoice_404InvoiceNotFound', () async {
      final response = await put(
        ApiPaths.invoiceItems(newId()),
        body([panadolLine()]),
      );

      expectProblem(response, HttpStatus.notFound, 'Invoice.NotFound');
    });

    test('101Lines_400ValidationFailed', () async {
      final response = await put(
        reviewItems(),
        body([for (var i = 1; i <= 101; i++) panadolLine(lineNo: i)]),
      );

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
      expect(json(response)['errors'], contains('items'));
    });

    test('100Lines_200', () async {
      final response = await put(
        reviewItems(),
        body([for (var i = 1; i <= 100; i++) panadolLine(lineNo: i)]),
      );

      expect(response.statusCode, HttpStatus.ok);
    });

    test('DuplicateLineNo_400ValidationFailed', () async {
      final response = await put(
        reviewItems(),
        body([panadolLine(), panadolLine()]),
      );

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
      expect(json(response)['errors'], contains('items[1].lineNo'));
    });

    test('JsonNumberQuantity_400ValidationFailedOnTheLine', () async {
      final response = await put(
        reviewItems(),
        body([panadolLine(), line(lineNo: 2, quantity: 10)]),
      );

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
      expect(json(response)['errors'], contains('items[1].quantity'));
    });

    test('ZeroQuantity_400PrecisionNotPositive', () async {
      final response = await put(
        reviewItems(),
        body([
          {...panadolLine(), 'quantity': '0.000'},
        ]),
      );

      expectProblem(response, HttpStatus.badRequest, 'Precision.NotPositive');
    });

    test('ThreeDecimalPrice_400PrecisionTooManyDecimals', () async {
      final response = await put(
        reviewItems(),
        body([
          {...panadolLine(), 'unitPrice': '1.005'},
        ]),
      );

      expectProblem(
        response,
        HttpStatus.badRequest,
        'Precision.TooManyDecimals',
      );
    });

    test('ProductAndNewProduct_400ValidationFailed', () async {
      final response = await put(
        reviewItems(),
        body([
          {
            ...panadolLine(),
            'newProduct': {
              'name': 'x',
              'baseUnitName': 'x',
              'sellPrice': '1.00',
            },
          },
        ]),
      );

      expectProblem(response, HttpStatus.badRequest, 'Validation.Failed');
    });
  });

  group('Fake Cairo time', () {
    test('SummerAndWinterOffsets', () {
      expect(
        FakeCairoTime.offsetAt(DateTime.utc(2026, 10, 12)),
        const Duration(hours: 3),
      );
      expect(
        FakeCairoTime.offsetAt(DateTime.utc(2026, 12, 2)),
        const Duration(hours: 2),
      );
      expect(
        FakeCairoTime.nextMidnight(DateTime.utc(2026, 12, 1, 7)),
        DateTime.utc(2026, 12, 1, 22),
      );
    });
  });

  group('InvoicesRemoteDataSource over the fake backend', () {
    late InvoicesRepositoryImpl repository;
    late InvoicesRemoteDataSource remote;

    setUp(() {
      final client = rawDio(adapter)
        ..options.headers[HttpHeaderNames.authorization] =
            '${HttpHeaderNames.bearerPrefix}$owner';
      remote = InvoicesRemoteDataSource(client);
      repository = InvoicesRepositoryImpl(remote);
    });

    test('Repository_ParsesEveryResponse', () async {
      final list = okValue(
        await repository.getInvoices(
          status: InvoiceStatus.needsReview,
          page: 1,
          pageSize: 20,
        ),
      );
      expect(list.items.map((i) => i.status).toSet(), {
        InvoiceStatus.needsReview,
      });

      final detail = okValue(
        await repository.getInvoice(FakeInvoiceSeed.needsReviewId),
      );
      expect(detail.warnings, [InvoiceWarning.totalMismatch]);
      expect(detail.items, hasLength(4));
      expect(detail.items.last.newProduct?.name, 'سيتال شراب');
      expect(detail.invoiceDate, const CalendarDate(2026, 10, 10));

      final draft = InvoiceDraft.fromDetail(detail);
      final saved = await repository.saveItems(
        detail.id,
        draft.copyWith(
          lines: [
            for (final line in draft.lines)
              if (line.choice is! UnresolvedChoice) line,
          ],
        ),
      );
      expect(okValue(saved).items, hasLength(3));
    });

    test('Repository_MapsTheErrorCode', () async {
      final detail = okValue(
        await repository.getInvoice(FakeInvoiceSeed.needsReviewId),
      );

      final result = await repository.saveItems(
        detail.id,
        InvoiceDraft.fromDetail(detail),
      );

      expect(
        (errOf(result) as ApiFailure).code,
        ApiErrorCode.invoiceLineProductRequired,
      );
    });

    test('Scan_202ThenRepeat200', () async {
      final file = File(
        '${(await Directory.systemTemp.createTemp('scan')).path}/x.jpg',
      )..writeAsBytesSync(Uint8List(16));
      final id = newId();

      final created = await remote.scan(
        clientRequestId: id,
        imagePath: file.path,
        shopId: state.shops.single.id,
      );
      final repeat = await remote.scan(
        clientRequestId: id,
        imagePath: file.path,
        shopId: state.shops.single.id,
      );

      expect(created.isRepeat, isFalse);
      expect(repeat.isRepeat, isTrue);
      expect(repeat.invoice.id, created.invoice.id);
    });

    test('RequestBody_MatchesTheContractFixture', () {
      final panadol = product('بنادول اكسترا');
      final request = InvoiceDraft(
        header: InvoiceHeaderDraft(
          supplierName: 'شركة الأدوية المتحدة',
          invoiceNumber: 'INV-1043',
          invoiceDate: const CalendarDate(2026, 10, 10),
          totalAmount: Money.fromApi('1250.00'),
        ),
        lines: [
          InvoiceLineDraft(
            lineNo: 1,
            rawName: 'بنادول اكسترا ٢٠ قرص',
            choice: LineProductChoice.existing(
              productId: panadol.id,
              productUnitId: panadol.baseUnit.id,
              productName: panadol.name,
              unitName: panadol.baseUnit.name,
            ),
            quantity: Quantity.fromApi('10.000'),
            unitPrice: Money.fromApi('120.00'),
            expiryDate: const CalendarDate(2027, 3, 31),
            batchNo: 'B12',
            lineTotal: Money.fromApi('1200.00'),
          ),
        ],
      ).toRequestJson();

      expectSameShape(request, fixture('update_invoice_items_request'));
      final line = (request['items']! as List<Object?>).single! as Map;
      expect(line.containsKey('lineTotal'), isFalse);
    });

    test('NewProductRequest_SendsTheObject', () {
      final request = InvoiceDraft(
        header: const InvoiceHeaderDraft(),
        lines: [
          InvoiceLineDraft(
            lineNo: 1,
            rawName: 'سيتال',
            choice: LineProductChoice.newProduct(
              NewProduct(
                name: 'سيتال شراب',
                baseUnitName: 'زجاجة',
                sellPrice: Money.fromApi('25.00'),
              ),
            ),
            quantity: Quantity.fromApi('6.000'),
            unitPrice: Money.fromApi('18.50'),
          ),
        ],
      ).toRequestJson();

      final line = (request['items']! as List<Object?>).single! as Map;
      expect(line['productId'], isNull);
      expect(line['newProduct'], {
        'name': 'سيتال شراب',
        'baseUnitName': 'زجاجة',
        'sellPrice': '25.00',
      });
      expect(line['quantity'], '6.000');
    });
  });

  test('FakeInvoiceRecords_LineTotalRounding', () {
    expect(
      FakeInvoicesHandler.lineTotalOf(
        Decimal.parse('0.333'),
        Decimal.parse('1.50'),
      ),
      Decimal.parse('0.50'),
    );
    expect(FakeInvoiceStatuses.all, hasLength(4));
  });
}

extension on InvoiceDraft {
  Map<String, Object?> toRequestJson() => toRequest().toJson();
}
