import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/decimal/unit_factor.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/products/domain/entities/product_lookup.dart';
import 'package:stockly/features/products/domain/entities/product_unit.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/features/sales/domain/entities/sale_input_rules.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';
import 'package:stockly/features/sales/presentation/providers/quick_sale_notifier.dart';
import 'package:stockly/features/sales/presentation/providers/quick_sale_state.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/dashboard_doubles.dart';
import '../../../helpers/products_doubles.dart' as products;
import '../../../helpers/sales_doubles.dart';
import '../../../helpers/test_doubles.dart';

const String _panadolBarcode = '6221234567890';
const String _boxBarcode = '6221234567906';

/// Design §11 quick-sale cart rules and §6.8 pending sales:
/// `QuickSaleNotifier` with mocked repositories.
void main() {
  late MockSalesRepository sales;
  late products.MockProductsRepository catalog;
  late CountingUuidGenerator uuid;

  setUpAll(() {
    registerSaleFallbacks();
    products.registerProductFallbacks();
  });

  setUp(() {
    sales = MockSalesRepository();
    catalog = products.MockProductsRepository();
    uuid = CountingUuidGenerator();
    when(() => catalog.lookupBarcode(_panadolBarcode)).thenAnswer(
      (_) async => Ok(
        ProductLookup(product: products.listItem(), unit: products.baseUnit),
      ),
    );
    when(() => catalog.lookupBarcode(_boxBarcode)).thenAnswer(
      (_) async => Ok(
        ProductLookup(product: products.listItem(), unit: products.boxUnit),
      ),
    );
    when(() => catalog.getProduct(products.productId))
        .thenAnswer((_) async => Ok(products.detail()));
    when(() => sales.discardPending(any())).thenAnswer((_) async {});
    when(() => sales.pendingSale(any())).thenAnswer((_) async => null);
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        salesRepositoryProvider.overrideWithValue(sales),
        productsRepositoryProvider.overrideWithValue(catalog),
        dashboardRepositoryProvider.overrideWithValue(quietDashboard()),
        currentSessionProvider.overrideWithValue(ownerSession),
        uuidGeneratorProvider.overrideWithValue(uuid),
        clockProvider.overrideWithValue(FakeClock()),
        appLoggerProvider.overrideWithValue(const NoopLogger()),
      ],
    );
    addTearDown(c.dispose);
    c.listen(quickSaleProvider, (_, _) {});
    return c;
  }

  QuickSaleNotifier notifierOf(ProviderContainer c) =>
      c.read(quickSaleProvider.notifier);

  void answerSubmit(Result<SaleSubmission, Failure> result) => when(
    () => sales.submit(
      any(),
      shopId: any(named: 'shopId'),
      userId: any(named: 'userId'),
    ),
  ).thenAnswer((_) async => result);

  List<SaleRequest> sentRequests() => verify(
    () => sales.submit(
      captureAny(),
      shopId: any(named: 'shopId'),
      userId: any(named: 'userId'),
    ),
  ).captured.cast<SaleRequest>();

  group('cart', () {
    test('Barcode_NewLineOfTheScannedUnitWithQuantityOne', () async {
      final c = container();
      await notifierOf(c).addBarcode('  $_boxBarcode ');

      final state = c.read(quickSaleProvider);
      expect(state.lines, hasLength(1));
      final line = state.lines.single;
      expect(line.unit, products.boxUnit);
      expect(line.units, [products.boxUnit]);
      expect(line.unitsLoaded, isFalse);
      expect(line.quantity, Quantity.one);
      expect(line.quantityText, '1');
      expect(line.priceOverride, isNull);
      expect(state.isLookingUp, isFalse);
      verify(() => catalog.lookupBarcode(_boxBarcode)).called(1);
    });

    test('SameBarcodeTwice_AddsOneToTheLine', () async {
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      await notifierOf(c).addBarcode(_panadolBarcode);

      final state = c.read(quickSaleProvider);
      expect(state.lines, hasLength(1));
      expect(state.lines.single.quantity, Quantity.fromApi('2.000'));
      expect(state.lines.single.quantityText, '2');
    });

    test('OtherUnitOfTheSameProduct_ItsOwnLine', () async {
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      await notifierOf(c).addBarcode(_boxBarcode);

      expect(c.read(quickSaleProvider).lines, hasLength(2));
    });

    test('BlankBarcode_NoLookup', () async {
      final c = container();
      await notifierOf(c).addBarcode('   ');

      verifyNever(() => catalog.lookupBarcode(any()));
    });

    test('UnknownBarcode_LookupFailureAndNoLine', () async {
      when(() => catalog.lookupBarcode('000'))
          .thenAnswer((_) async => const Err(products.productNotFound));
      final c = container();
      await notifierOf(c).addBarcode('000');

      final state = c.read(quickSaleProvider);
      expect(state.lines, isEmpty);
      expect(state.lookupFailure, products.productNotFound);
      await notifierOf(c).addBarcode(_panadolBarcode);
      expect(c.read(quickSaleProvider).lookupFailure, isNull);
    });

    test('SearchedProduct_AllUnitsWithTheBaseUnit', () async {
      final c = container();
      await notifierOf(c).addProduct(products.listItem());

      final line = c.read(quickSaleProvider).lines.single;
      expect(line.unit, products.baseUnit);
      expect(line.units, [products.baseUnit, products.boxUnit]);
      expect(line.unitsLoaded, isTrue);
      verify(() => catalog.getProduct(products.productId)).called(1);
    });

    test('LoadUnits_FetchesTheProductOnce', () async {
      final c = container();
      await notifierOf(c).addBarcode(_boxBarcode);
      final key = c.read(quickSaleProvider).lines.single.key;

      await notifierOf(c).loadUnits(key);
      await notifierOf(c).loadUnits(key);

      final line = c.read(quickSaleProvider).lines.single;
      expect(line.units, [products.baseUnit, products.boxUnit]);
      expect(line.unitsLoaded, isTrue);
      verify(() => catalog.getProduct(products.productId)).called(1);
    });

    test('SetUnit_DropsThePriceOverride', () async {
      final c = container();
      await notifierOf(c).addProduct(products.listItem());
      final key = c.read(quickSaleProvider).lines.single.key;
      notifierOf(c)
        ..setPrice(key, '14.00')
        ..setUnit(key, products.boxUnitId);

      final line = c.read(quickSaleProvider).lines.single;
      expect(line.unit, products.boxUnit);
      expect(line.priceText, isEmpty);
      expect(line.priceOverride, isNull);
      expect(line.price, products.boxUnit.sellPrice);
    });

    test('Quantity_PositiveWithThreeDecimalsAtMost', () async {
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      final key = c.read(quickSaleProvider).lines.single.key;
      final notifier = notifierOf(c);

      for (final (text, issue) in [
        ('0', SaleFieldIssue.notPositive),
        ('-1', SaleFieldIssue.negative),
        ('1.2345', SaleFieldIssue.tooManyDecimals),
        ('', SaleFieldIssue.required),
        ('abc', SaleFieldIssue.invalidNumber),
      ]) {
        notifier.setQuantity(key, text);
        expect(
          c.read(quickSaleProvider).lines.single.quantityIssue,
          issue,
          reason: text,
        );
        expect(c.read(quickSaleProvider).canSubmit, isFalse, reason: text);
      }
      notifier.setQuantity(key, '١٫٥');
      final line = c.read(quickSaleProvider).lines.single;
      expect(line.quantity, Quantity.fromApi('1.500'));
      expect(line.quantityIssue, isNull);
      expect(line.totalPreview, Money.fromApi('22.50'));
    });

    test('PriceOverride_BlankIsTheListPrice', () async {
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      final key = c.read(quickSaleProvider).lines.single.key;
      final notifier = notifierOf(c)..setPrice(key, '12.5');

      var line = c.read(quickSaleProvider).lines.single;
      expect(line.priceOverride, Money.fromApi('12.50'));
      expect(line.price, Money.fromApi('12.50'));

      notifier.setPrice(key, '1.234');
      line = c.read(quickSaleProvider).lines.single;
      expect(line.priceIssue, SaleFieldIssue.tooManyDecimals);

      notifier.setPrice(key, '-1');
      expect(
        c.read(quickSaleProvider).lines.single.priceIssue,
        SaleFieldIssue.negative,
      );

      notifier.setPrice(key, '');
      line = c.read(quickSaleProvider).lines.single;
      expect(line.priceOverride, isNull);
      expect(line.priceIssue, isNull);
      expect(line.price, products.baseUnit.sellPrice);
    });

    test('HundredLines_TheNextIsRefused', () async {
      final c = container();
      for (var i = 0; i < SaleRules.maxLines + 1; i++) {
        final barcode = 'code-$i';
        final id = '0192f0a0-6c1e-7b3a-9d2e-a${'$i'.padLeft(11, '0')}';
        when(() => catalog.lookupBarcode(barcode)).thenAnswer(
          (_) async => Ok(
            ProductLookup(
              product: products.listItem(id: id),
              unit: ProductUnit(
                id: '0192f0a0-6c1e-7b3a-9d2e-b${'$i'.padLeft(11, '0')}',
                name: 'شريط',
                factor: UnitFactor.fromApi('1.000000'),
                sellPrice: Money.fromApi('1.00'),
                barcode: barcode,
                isBase: true,
              ),
            ),
          ),
        );
        await notifierOf(c).addBarcode(barcode);
      }

      final state = c.read(quickSaleProvider);
      expect(state.lines, hasLength(SaleRules.maxLines));
      expect(state.lineLimitReached, isTrue);

      notifierOf(c).removeLine(state.lines.first.key);
      expect(c.read(quickSaleProvider).lineLimitReached, isFalse);
    });

    test('RemoveAndClear', () async {
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      await notifierOf(c).addBarcode(_boxBarcode);
      notifierOf(c).removeLine(c.read(quickSaleProvider).lines.first.key);
      expect(c.read(quickSaleProvider).lines.single.unit, products.boxUnit);

      notifierOf(c).clear();
      expect(c.read(quickSaleProvider).lines, isEmpty);
    });
  });

  group('submit', () {
    test('InvalidLine_FlaggedAndNothingSent', () async {
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      final key = c.read(quickSaleProvider).lines.single.key;
      notifierOf(c).setQuantity(key, '0');

      await notifierOf(c).submit();

      expect(c.read(quickSaleProvider).lineErrors, {key});
      verifyNever(
        () => sales.submit(
          any(),
          shopId: any(named: 'shopId'),
          userId: any(named: 'userId'),
        ),
      );
      expect(uuid.count, 0);
    });

    test('Created_RequestShapeAndCartEmptied', () async {
      answerSubmit(Ok(SaleSubmission.created(sale())));
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      await notifierOf(c).addBarcode(_boxBarcode);
      final keys = c.read(quickSaleProvider).lines.map((l) => l.key).toList();
      notifierOf(c)
        ..setQuantity(keys.first, '2')
        ..setPrice(keys.last, '38.50')
        ..setNote('  دفع كاش ');

      await notifierOf(c).submit();

      final captured = verify(
        () => sales.submit(
          captureAny(),
          shopId: captureAny(named: 'shopId'),
          userId: captureAny(named: 'userId'),
        ),
      ).captured;
      expect(captured.sublist(1), [ownerSession.shop.id, ownerSession.user.id]);
      final request = captured.first as SaleRequest;
      expect(request.note, 'دفع كاش');
      expect(request.items, [
        SaleRequestItem(
          productId: products.productId,
          productUnitId: products.baseUnitId,
          quantity: Quantity.fromApi('2.000'),
          unitPrice: null,
        ),
        SaleRequestItem(
          productId: products.productId,
          productUnitId: products.boxUnitId,
          quantity: Quantity.one,
          unitPrice: Money.fromApi('38.50'),
        ),
      ]);
      final state = c.read(quickSaleProvider);
      expect(state.lines, isEmpty);
      expect(state.phase, QuickSalePhase.editing);
      expect(state.clientRequestId, isNull);
      expect(state.submissionCount, 1);
      expect(state.lastSubmission, SaleSubmission.created(sale()));
      expect(uuid.count, 1);
    });

    test('Submitting_PhaseWhileTheRequestRuns', () async {
      final pending = Completer<Result<SaleSubmission, Failure>>();
      when(
        () => sales.submit(
          any(),
          shopId: any(named: 'shopId'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) => pending.future);
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);

      final done = notifierOf(c).submit();
      expect(c.read(quickSaleProvider).phase, QuickSalePhase.submitting);
      await notifierOf(c).addBarcode(_boxBarcode);
      expect(c.read(quickSaleProvider).lines, hasLength(1));

      pending.complete(Ok(SaleSubmission.created(sale())));
      await done;
      expect(c.read(quickSaleProvider).phase, QuickSalePhase.editing);
    });

    test('UnknownOutcome_LockedAndRetrySendsTheSameSale', () async {
      answerSubmit(const Err(NetworkFailure()));
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);

      await notifierOf(c).submit();

      var state = c.read(quickSaleProvider);
      expect(state.phase, QuickSalePhase.lockedUnknownOutcome);
      expect(state.failure, const NetworkFailure());
      expect(state.lines, hasLength(1));
      final id = state.clientRequestId;
      expect(id, isNotNull);
      expect(state.lockedRequest?.clientRequestId, id);
      expect(state.lockedSince, FakeClock().now());

      // Locked: the cart cannot change.
      final key = state.lines.single.key;
      notifierOf(c)
        ..setQuantity(key, '5')
        ..removeLine(key)
        ..clear();
      await notifierOf(c).addBarcode(_boxBarcode);
      await notifierOf(c).submit();
      state = c.read(quickSaleProvider);
      expect(state.lines.single.quantityText, '1');
      verify(() => catalog.lookupBarcode(any())).called(1);

      answerSubmit(const Err(TimeoutFailure()));
      await notifierOf(c).retry();
      expect(c.read(quickSaleProvider).isLocked, isTrue);

      answerSubmit(Ok(SaleSubmission.alreadyRecorded(sale())));
      await notifierOf(c).retry();

      final requests = sentRequests();
      expect(requests, hasLength(3));
      expect(requests.toSet(), hasLength(1), reason: 'same id, same body');
      expect(requests.first.clientRequestId, id);
      expect(uuid.count, 1);
      state = c.read(quickSaleProvider);
      expect(state.phase, QuickSalePhase.editing);
      expect(state.lines, isEmpty);
      expect(state.lastSubmission, SaleSubmission.alreadyRecorded(sale()));
    });

    test('ServerOrUnknownApiFailure_AlsoLocks', () async {
      for (final failure in <Failure>[
        serverFailure,
        const UnknownApiFailure(info: ApiProblemInfo(status: 502)),
        const MalformedResponseFailure(),
      ]) {
        answerSubmit(Err(failure));
        final c = container();
        await notifierOf(c).addBarcode(_panadolBarcode);
        await notifierOf(c).submit();
        expect(c.read(quickSaleProvider).isLocked, isTrue, reason: '$failure');
      }
    });

    test('DefiniteFailure_UnlocksAndTheNextSubmitHasANewId', () async {
      answerSubmit(const Err(archivedProduct));
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);

      await notifierOf(c).submit();

      final state = c.read(quickSaleProvider);
      expect(state.phase, QuickSalePhase.editing);
      expect(state.failure, archivedProduct);
      expect(state.clientRequestId, isNull);
      expect(state.lines, hasLength(1));

      answerSubmit(Ok(SaleSubmission.created(sale())));
      await notifierOf(c).submit();
      final requests = sentRequests();
      expect(requests, hasLength(2));
      expect(
        requests.first.clientRequestId,
        isNot(requests.last.clientRequestId),
      );
      expect(uuid.count, 2);
    });

    test('ValidationFailure_MessagesOnTheirLines', () async {
      answerSubmit(
        const Err(
          ValidationFailure(
            ApiErrorCode.validationFailed,
            ApiProblemInfo(status: HttpStatus.badRequest),
            fieldErrors: {
              'items[1].quantity': ['must be positive'],
              'note': ['too long'],
            },
          ),
        ),
      );
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      await notifierOf(c).addBarcode(_boxBarcode);
      final second = c.read(quickSaleProvider).lines.last.key;

      await notifierOf(c).submit();

      expect(c.read(quickSaleProvider).lineMessages, {
        second: ['must be positive'],
      });
      notifierOf(c).setQuantity(second, '3');
      expect(c.read(quickSaleProvider).lineMessages, isEmpty);
    });

    test('Discard_DropsTheLockedSaleAndEmptiesTheCart', () async {
      answerSubmit(const Err(NetworkFailure()));
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);
      await notifierOf(c).submit();
      final id = c.read(quickSaleProvider).clientRequestId!;

      await notifierOf(c).discard();

      verify(() => sales.discardPending(id)).called(1);
      final state = c.read(quickSaleProvider);
      expect(state.phase, QuickSalePhase.editing);
      expect(state.lines, isEmpty);
      expect(state.clientRequestId, isNull);
    });
  });

  group('restore', () {
    test('PendingSaleOfTheShop_ReopensLocked', () async {
      when(() => sales.pendingSale(ownerSession.shop.id))
          .thenAnswer((_) async => pendingSale());
      final c = container();

      await notifierOf(c).restorePending();

      final state = c.read(quickSaleProvider);
      expect(state.isLocked, isTrue);
      expect(state.clientRequestId, saleRequestId);
      expect(state.lockedRequest, saleRequest());
      expect(state.lockedLineCount, 1);
      expect(state.lockedSince, DateTime.utc(2026, 10, 12, 7));

      answerSubmit(Ok(SaleSubmission.alreadyRecorded(sale())));
      await notifierOf(c).retry();
      expect(sentRequests().single, saleRequest());
    });

    test('NothingPending_StaysEditing', () async {
      final c = container();
      await notifierOf(c).restorePending();

      expect(c.read(quickSaleProvider).isEditable, isTrue);
    });

    test('CartInUse_NotReplaced', () async {
      when(() => sales.pendingSale(any()))
          .thenAnswer((_) async => pendingSale());
      final c = container();
      await notifierOf(c).addBarcode(_panadolBarcode);

      await notifierOf(c).restorePending();

      expect(c.read(quickSaleProvider).isEditable, isTrue);
      verifyNever(() => sales.pendingSale(any()));
    });
  });
}
