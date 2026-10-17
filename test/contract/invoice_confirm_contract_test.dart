import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_product_records.dart';
import 'package:stockly/core/fake_backend/seed/fake_invoice_seed.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/repositories/invoices_repository_impl.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';

import '../helpers/fake_app.dart';
import '../helpers/products_doubles.dart' show errOf, okValue;
import '../helpers/test_doubles.dart';
import 'json_shape.dart';

/// Contract I5 (v1.4 §6) against the fake backend: lines without a
/// product are refused, every line is received in base units through a
/// movement, new products are created, a repeat changes nothing, and only
/// a `NeedsReview` invoice can be confirmed.
void main() {
  late FakeClock clock;
  late FakeBackendState state;
  late FakeBackendAdapter adapter;
  late Dio dio;
  late String owner;

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

  void expectProblem(Response<Object?> response, int status, String code) {
    expect(response.statusCode, status, reason: '${response.data}');
    expect(json(response)['code'], code);
  }

  FakeProduct product(String name) =>
      state.products.firstWhere((p) => p.name == name);

  Future<Response<Object?>> confirm(String invoiceId, {String? token}) =>
      dio.post<Object?>(
        ApiPaths.invoiceConfirm(invoiceId),
        options: auth(token: token),
      );

  /// Resolves the seeded review invoice's line without a product (line 3)
  /// to Panadol's base unit.
  Future<void> resolveReview() async {
    final panadol = product('بنادول اكسترا');
    final congestal = product('كونجستال');
    Map<String, Object?> line(
      int lineNo,
      String quantity,
      String price, {
      FakeProduct? of,
      FakeUnit? unit,
      Map<String, Object?>? newProduct,
    }) => {
      'lineNo': lineNo,
      'rawName': 'line $lineNo',
      'productId': of?.id,
      'productUnitId': of == null ? null : (unit ?? of.baseUnit).id,
      'newProduct': newProduct,
      'quantity': quantity,
      'unitPrice': price,
      'expiryDate': lineNo == 1 ? '2027-03-31' : null,
      'batchNo': null,
    };
    final response = await dio.put<Object?>(
      ApiPaths.invoiceItems(FakeInvoiceSeed.needsReviewId),
      data: {
        'supplierName': 'شركة الأدوية المتحدة',
        'invoiceNumber': 'INV-1043',
        'invoiceDate': '2026-10-10',
        'totalAmount': '1250.00',
        'items': [
          line(1, '10.000', '36.00', of: panadol, unit: panadol.units.last),
          line(2, '12.000', '14.00', of: congestal),
          line(3, '5.000', '12.00', of: panadol),
          line(
            4,
            '6.000',
            '18.50',
            newProduct: {
              'name': 'سيتال شراب',
              'baseUnitName': 'زجاجة',
              'sellPrice': '25.00',
            },
          ),
        ],
      },
      options: auth(),
    );
    expect(response.statusCode, HttpStatus.ok, reason: '${response.data}');
  }

  test('UnresolvedLine_400LineProductRequired_NothingReceived', () async {
    final movements = state.movements.length;

    final response = await confirm(FakeInvoiceSeed.needsReviewId);

    expectProblem(
      response,
      HttpStatus.badRequest,
      ApiErrorCode.invoiceLineProductRequired.wire,
    );
    expect(state.movements, hasLength(movements));
  });

  test('Confirm_200ReceivesEveryLineInBaseUnits', () async {
    await resolveReview();
    final panadol = product('بنادول اكسترا');
    final congestal = product('كونجستال');
    final panadolBefore = panadol.quantity;
    final congestalBefore = congestal.quantity;

    final response = await confirm(FakeInvoiceSeed.needsReviewId);

    expect(response.statusCode, HttpStatus.ok, reason: '${response.data}');
    final body = json(response);
    expectSameShape(body, fixture('invoice_detail'), enums: invoiceEnums);
    expect(body['status'], 'Confirmed');
    expect(body['confirmedAt'], clock.now().toIso8601String());
    // 10 boxes × 3 strips + 5 strips.
    expect(panadol.quantity, panadolBefore + Decimal.fromInt(35));
    expect(congestal.quantity, congestalBefore + Decimal.fromInt(12));
    final sital = product('سيتال شراب');
    expect(sital.quantity, Decimal.fromInt(6));
    expect(sital.costPrice, Decimal.parse('18.50'));
    expect(sital.baseUnit.name, 'زجاجة');
    expect(sital.baseUnit.sellPrice, Decimal.parse('25.00'));
    final receipts = state.movements
        .where((m) => m.invoiceId == FakeInvoiceSeed.needsReviewId)
        .toList();
    expect(receipts, hasLength(4));
    expect(
      receipts.every((m) => m.reason == FakeMovementReasons.invoiceReceipt),
      isTrue,
    );
    final items = (body['items']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final created = items.firstWhere((i) => i['lineNo'] == 4);
    expect(created['productId'], sital.id);
    expect(created['productName'], 'سيتال شراب');
    expect(created['newProduct'], isNotNull);
  });

  test('Repeat_200SameInvoiceAndNoNewMovements', () async {
    await resolveReview();
    final first = await confirm(FakeInvoiceSeed.needsReviewId);
    final movements = state.movements.length;
    final products = state.products.length;

    final repeat = await confirm(FakeInvoiceSeed.needsReviewId);

    expect(repeat.statusCode, HttpStatus.ok);
    expect(json(repeat), json(first));
    expect(state.movements, hasLength(movements));
    expect(state.products, hasLength(products));
  });

  test('ProcessingOrFailed_409NotConfirmable', () async {
    for (final id in [FakeInvoiceSeed.processingId, FakeInvoiceSeed.failedId]) {
      expectProblem(
        await confirm(id),
        HttpStatus.conflict,
        ApiErrorCode.invoiceNotConfirmable.wire,
      );
    }
  });

  test('Confirmed_EditIsNowRefused', () async {
    await resolveReview();
    await confirm(FakeInvoiceSeed.needsReviewId);

    final edit = await dio.put<Object?>(
      ApiPaths.invoiceItems(FakeInvoiceSeed.needsReviewId),
      data: const {'items': <Object?>[]},
      options: auth(),
    );

    expect(edit.statusCode, HttpStatus.badRequest);
  });

  test('UnknownInvoice_404AndNoToken_401', () async {
    expectProblem(
      await confirm('0192f0a0-6c1e-7b3a-9d2e-e00000009999'),
      HttpStatus.notFound,
      ApiErrorCode.invoiceNotFound.wire,
    );
    expectProblem(
      await confirm(FakeInvoiceSeed.needsReviewId, token: 'nope'),
      HttpStatus.unauthorized,
      ApiErrorCode.authUnauthenticated.wire,
    );
  });

  test('Repository_ConfirmParsesAndMapsFailures', () async {
    final client = rawDio(adapter)
      ..options.headers[HttpHeaderNames.authorization] =
          '${HttpHeaderNames.bearerPrefix}$owner';
    final repository = InvoicesRepositoryImpl(InvoicesRemoteDataSource(client));

    final refused = errOf(
      await repository.confirm(FakeInvoiceSeed.needsReviewId),
    );
    expect(refused, isA<InvalidInputFailure>());
    final conflict = errOf(
      await repository.confirm(FakeInvoiceSeed.processingId),
    );
    expect(
      (conflict as ConflictFailure).code,
      ApiErrorCode.invoiceNotConfirmable,
    );

    await resolveReview();
    final confirmed = okValue(
      await repository.confirm(FakeInvoiceSeed.needsReviewId),
    );
    expect(confirmed.status, InvoiceStatus.confirmed);
    expect(confirmed.confirmedAt, clock.now());
  });
}
