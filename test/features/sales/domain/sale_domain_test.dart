import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/features/sales/domain/entities/sale.dart';
import 'package:stockly/features/sales/domain/entities/sale_date_range.dart';
import 'package:stockly/features/sales/domain/entities/sale_input_rules.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/domain/entities/sale_outcome.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';
import 'package:stockly/features/sales/domain/usecases/discard_pending_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/get_pending_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/get_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/get_sales_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/submit_sale_use_case.dart';
import 'package:stockly/features/sales/domain/usecases/watch_pending_sale_use_case.dart';

import '../../../helpers/products_doubles.dart' as products;
import '../../../helpers/sales_doubles.dart';

const String _shopId = '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d01';

CartLine _line({String quantity = '2', Money? override}) {
  final parsed = SaleInputRules.quantity(quantity);
  return CartLine(
    key: 1,
    productId: products.productId,
    productName: 'بنادول اكسترا',
    unit: products.baseUnit,
    units: [products.baseUnit],
    stock: Quantity.fromApi('10.000'),
    baseUnitName: 'شريط',
    quantityText: quantity,
    quantity: parsed.value,
    quantityIssue: parsed.issue,
    priceOverride: override,
  );
}

/// Sales domain rules (design §11 cart rules, §6.8) and use cases.
void main() {
  setUpAll(registerSaleFallbacks);

  group('SaleInputRules', () {
    test('Quantity_ExactNeverRounded', () {
      expect(SaleInputRules.quantity('1.5').value, Quantity.fromApi('1.500'));
      expect(SaleInputRules.quantity('٢').value, Quantity.fromApi('2.000'));
      expect(
        SaleInputRules.quantity('0.0001').issue,
        SaleFieldIssue.tooManyDecimals,
      );
      expect(SaleInputRules.quantity('0').issue, SaleFieldIssue.notPositive);
      expect(SaleInputRules.quantity('').issue, SaleFieldIssue.required);
      expect(
        SaleInputRules.quantity('1' * 18).issue,
        SaleFieldIssue.outOfRange,
      );
    });

    test('PriceOverride_BlankIsNoOverride', () {
      final blank = SaleInputRules.priceOverride('  ');
      expect(blank.value, isNull);
      expect(blank.issue, isNull);
      expect(SaleInputRules.priceOverride('0').value, Money.zero);
      expect(
        SaleInputRules.priceOverride('12.345').issue,
        SaleFieldIssue.tooManyDecimals,
      );
      expect(SaleInputRules.priceOverride('-1').issue, SaleFieldIssue.negative);
      expect(
        SaleInputRules.priceOverride('x').issue,
        SaleFieldIssue.invalidNumber,
      );
    });
  });

  group('CartLine', () {
    test('Preview_ListPriceUnlessOverridden', () {
      expect(_line().price, Money.fromApi('15.00'));
      expect(_line().totalPreview, Money.fromApi('30.00'));
      final cheaper = _line(override: Money.fromApi('12.50'));
      expect(cheaper.price, Money.fromApi('12.50'));
      expect(cheaper.toRequestItem().unitPrice, Money.fromApi('12.50'));
      expect(_line().toRequestItem().unitPrice, isNull);
    });

    test('Preview_RoundedToPiasters', () {
      final line = _line(quantity: '0.333', override: Money.fromApi('10.00'));
      expect(line.totalPreview, Money.fromApi('3.33'));
    });

    test('InvalidQuantity_NoPreviewAndNotValid', () {
      final line = _line(quantity: '0');
      expect(line.totalPreview, isNull);
      expect(line.isValid, isFalse);
      expect(cartTotalPreview([line, _line()]), Money.fromApi('30.00'));
    });
  });

  group('SaleDateRange', () {
    test('FromTheLocalMidnight', () {
      final now = DateTime.utc(2026, 10, 12, 9);
      final local = now.toLocal();
      final midnight = DateTime(local.year, local.month, local.day);
      expect(SaleDateRange.today.fromUtc(now), midnight.toUtc());
      expect(
        SaleDateRange.lastSevenDays.fromUtc(now),
        DateTime(local.year, local.month, local.day - 6).toUtc(),
      );
      expect(SaleDateRange.all.fromUtc(now), isNull);
    });
  });

  group('SaleOutcome', () {
    test('OnlyTransportAndServerFailuresLeaveItUnknown', () {
      const info = ApiProblemInfo(status: 400);
      for (final failure in <Failure>[
        const NetworkFailure(),
        const TimeoutFailure(),
        serverFailure,
        const UnknownApiFailure(info: info),
        const MalformedResponseFailure(),
      ]) {
        expect(failure.leavesSaleOutcomeUnknown, isTrue, reason: '$failure');
      }
      for (final failure in <Failure>[
        archivedProduct,
        saleNotFound,
        const ValidationFailure(
          ApiErrorCode.validationFailed,
          info,
          fieldErrors: {},
        ),
        const SessionEndedFailure(ApiErrorCode.authUnauthenticated, info),
        const ShopSuspendedFailure(ApiErrorCode.shopSuspended, info),
      ]) {
        expect(failure.leavesSaleOutcomeUnknown, isFalse, reason: '$failure');
      }
    });
  });

  test('Sale_NegativeStockProductNames', () {
    expect(sale(negative: true).negativeStockProducts, ['بنادول اكسترا']);
    expect(sale().negativeStockProducts, isEmpty);
  });

  group('use cases', () {
    late MockSalesRepository repository;

    setUp(() => repository = MockSalesRepository());

    test('SubmitSale_PassesTheSessionScope', () async {
      when(
        () => repository.submit(
          any(),
          shopId: any(named: 'shopId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => Ok(SaleSubmission.created(sale())));

      final result = await SubmitSaleUseCase(repository)
          .call(saleRequest(), shopId: _shopId, userId: saleUserId);

      expect(result, isA<Ok<SaleSubmission, Failure>>());
      verify(
        () => repository.submit(
          saleRequest(),
          shopId: _shopId,
          userId: saleUserId,
        ),
      ).called(1);
    });

    test('SubmitSale_FailureUnchanged', () async {
      when(
        () => repository.submit(
          any(),
          shopId: any(named: 'shopId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async => const Err(archivedProduct));

      final result = await SubmitSaleUseCase(repository)
          .call(saleRequest(), shopId: _shopId, userId: saleUserId);

      expect((result as Err).failure, archivedProduct);
    });

    test('GetSales_RangeBoundAndPageSize', () async {
      final now = DateTime.utc(2026, 10, 12, 9);
      when(
        () => repository.getSales(
          from: any(named: 'from'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          Paged<SaleListItem>(
            items: [saleListItem()],
            page: 2,
            pageSize: 20,
            totalCount: 21,
          ),
        ),
      );

      await GetSalesUseCase(repository)
          .call(SaleDateRange.today, now: now, page: 2);

      verify(
        () => repository.getSales(
          from: SaleDateRange.today.fromUtc(now),
          page: 2,
          pageSize: SalePaging.pageSize,
        ),
      ).called(1);
    });

    test('GetSale_NotFound', () async {
      when(() => repository.getSale(saleId))
          .thenAnswer((_) async => const Err(saleNotFound));

      final result = await GetSaleUseCase(repository).call(saleId);

      expect((result as Err).failure, saleNotFound);
    });

    test('PendingSale_GetWatchDiscard', () async {
      when(() => repository.pendingSale(_shopId))
          .thenAnswer((_) async => pendingSale());
      when(() => repository.watchPendingSale(_shopId))
          .thenAnswer((_) => Stream.value(null));
      when(() => repository.discardPending(saleRequestId))
          .thenAnswer((_) async {});

      expect(
        await GetPendingSaleUseCase(repository).call(_shopId),
        pendingSale(),
      );
      expect(
        await WatchPendingSaleUseCase(repository).call(_shopId).first,
        isNull,
      );
      await DiscardPendingSaleUseCase(repository).call(saleRequestId);
      verify(() => repository.discardPending(saleRequestId)).called(1);
    });
  });
}
