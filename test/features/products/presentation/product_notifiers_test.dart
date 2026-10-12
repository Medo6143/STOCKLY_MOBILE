import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/products/domain/entities/product_draft.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/domain/entities/stock_change_drafts.dart';
import 'package:stockly/features/products/domain/entities/unit_draft.dart';
import 'package:stockly/features/products/presentation/providers/movement_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_detail_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_form_notifier.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/features/products/presentation/providers/stock_adjustment_notifier.dart';
import 'package:stockly/features/products/presentation/providers/stock_count_notifier.dart';
import 'package:stockly/features/products/presentation/providers/unit_form_notifier.dart';
import 'package:stockly/features/products/presentation/providers/unit_form_state.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/products_doubles.dart';

/// Every products notifier with a `ProviderContainer` and a mocked
/// repository (design §13.1).
void main() {
  late MockProductsRepository repository;

  setUpAll(registerProductFallbacks);
  setUp(() => repository = MockProductsRepository());

  ProviderContainer container({Session? session}) {
    final container = ProviderContainer(
      overrides: [
        productsRepositoryProvider.overrideWithValue(repository),
        currentSessionProvider.overrideWithValue(session ?? ownerSession),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    return container;
  }

  void stubProducts(
    Future<Result<Paged<ProductListItem>, Failure>> Function(int page) answer,
  ) => when(
    () => repository.getProducts(
      any(),
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((i) => answer(i.namedArguments[#page] as int));

  group('ProductListNotifier', () {
    const query = ProductQuery(lowStock: true);

    test('Build_FirstPage_Data', () async {
      stubProducts((_) async => Ok(page([listItem()], totalCount: 1)));
      final c = container()..listen(productListProvider(query), (_, _) {});

      final state = await c.read(productListProvider(query).future);

      expect(state.items, [listItem()]);
      expect(state.hasMore, isFalse);
      verify(() => repository.getProducts(query, page: 1, pageSize: 20))
          .called(1);
    });

    test('Build_Empty_EmptyItems', () async {
      stubProducts((_) async => Ok(page<ProductListItem>(const [])));
      final c = container()..listen(productListProvider(query), (_, _) {});

      final state = await c.read(productListProvider(query).future);

      expect(state.items, isEmpty);
    });

    test('Build_Failure_AsyncErrorWithTheFailure', () async {
      stubProducts((_) async => const Err(NetworkFailure()));
      final c = container()..listen(productListProvider(query), (_, _) {});

      await expectLater(
        c.read(productListProvider(query).future),
        throwsA(isA<NetworkFailure>()),
      );
      expect(c.read(productListProvider(query)).error, isA<NetworkFailure>());
    });

    test('LoadMore_AppendsTheNextPage_OnceAtATime', () async {
      final second = Completer<Result<Paged<ProductListItem>, Failure>>();
      stubProducts(
        (p) => p == 1
            ? Future.value(Ok(page([listItem(id: 'a')], totalCount: 21)))
            : second.future,
      );
      final c = container()..listen(productListProvider(query), (_, _) {});
      await c.read(productListProvider(query).future);
      final notifier = c.read(productListProvider(query).notifier);

      final loading = notifier.loadMore();
      unawaited(notifier.loadMore());
      expect(c.read(productListProvider(query)).value!.isLoadingMore, isTrue);
      second.complete(Ok(page([listItem(id: 'b')], page: 2, totalCount: 21)));
      await loading;

      final state = c.read(productListProvider(query)).value!;
      expect(state.items.map((i) => i.id), ['a', 'b']);
      expect(state.page, 2);
      expect(state.isLoadingMore, isFalse);
      verify(() => repository.getProducts(query, page: 2, pageSize: 20))
          .called(1);
    });

    test('LoadMore_Failure_KeepsDataWithInlineFailure', () async {
      stubProducts(
        (p) async => p == 1
            ? Ok(page([listItem()], totalCount: 40))
            : const Err(TimeoutFailure()),
      );
      final c = container()..listen(productListProvider(query), (_, _) {});
      await c.read(productListProvider(query).future);

      await c.read(productListProvider(query).notifier).loadMore();

      final state = c.read(productListProvider(query)).value!;
      expect(state.items, [listItem()]);
      expect(state.loadMoreFailure, isA<TimeoutFailure>());
    });

    test('LoadMore_NoMorePages_DoesNothing', () async {
      stubProducts((_) async => Ok(page([listItem()])));
      final c = container()..listen(productListProvider(query), (_, _) {});
      await c.read(productListProvider(query).future);

      await c.read(productListProvider(query).notifier).loadMore();

      verify(
        () => repository.getProducts(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(1);
    });
  });

  group('MovementListNotifier', () {
    test('Build_AndLoadMore_PagesNewestFirst', () async {
      when(
        () => repository.getMovements(
          productId,
          page: any(named: 'page'),
          pageSize: 20,
        ),
      ).thenAnswer(
        (i) async => i.namedArguments[#page] == 1
            ? Ok(page([movement(id: 'm2')], totalCount: 21))
            : Ok(page([movement(id: 'm1')], page: 2, totalCount: 21)),
      );
      final c = container()..listen(movementListProvider(productId), (_, _) {});

      await c.read(movementListProvider(productId).future);
      await c.read(movementListProvider(productId).notifier).loadMore();

      final state = c.read(movementListProvider(productId)).value!;
      expect(state.items.map((m) => m.id), ['m2', 'm1']);
    });

    test('Build_NotFound_Error', () async {
      when(
        () => repository.getMovements(
          productId,
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => const Err(productNotFound));
      final c = container()..listen(movementListProvider(productId), (_, _) {});

      await expectLater(
        c.read(movementListProvider(productId).future),
        throwsA(productNotFound),
      );
    });
  });

  group('ProductDetailNotifier', () {
    test('Build_Data_AndNotFound', () async {
      when(() => repository.getProduct(productId))
          .thenAnswer((_) async => Ok(detail()));
      when(() => repository.getProduct(boxUnitId))
          .thenAnswer((_) async => const Err(productNotFound));
      final c = container()
        ..listen(productDetailProvider(productId), (_, _) {})
        ..listen(productDetailProvider(boxUnitId), (_, _) {});

      expect(await c.read(productDetailProvider(productId).future), detail());
      await expectLater(
        c.read(productDetailProvider(boxUnitId).future),
        throwsA(productNotFound),
      );
    });

    test('Archive_Ok_ReloadsTheProductAndTheList', () async {
      var archived = false;
      when(() => repository.getProduct(productId))
          .thenAnswer((_) async => Ok(detail(isArchived: archived)));
      when(() => repository.archiveProduct(productId)).thenAnswer((_) async {
        archived = true;
        return const Ok(null);
      });
      stubProducts((_) async => Ok(page([listItem()])));
      final c = container()
        ..listen(productDetailProvider(productId), (_, _) {})
        ..listen(productListProvider(const ProductQuery()), (_, _) {});
      await c.read(productDetailProvider(productId).future);
      await c.read(productListProvider(const ProductQuery()).future);

      final failure = await c
          .read(productDetailProvider(productId).notifier)
          .archive();

      expect(failure, isNull);
      final reloaded = await c.read(productDetailProvider(productId).future);
      expect(reloaded.isArchived, isTrue);
      await c.read(productListProvider(const ProductQuery()).future);
      verify(
        () => repository.getProducts(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).called(2);
    });

    test('Archive_Forbidden_ReturnsTheFailure', () async {
      when(() => repository.getProduct(productId))
          .thenAnswer((_) async => Ok(detail()));
      when(() => repository.archiveProduct(productId))
          .thenAnswer((_) async => const Err(forbidden));
      final c = container(session: staffSession)
        ..listen(productDetailProvider(productId), (_, _) {});
      await c.read(productDetailProvider(productId).future);

      final failure = await c
          .read(productDetailProvider(productId).notifier)
          .archive();

      expect(failure, forbidden);
    });
  });

  group('ProductFormNotifier', () {
    ProductFormInput input({
      String name = 'بنادول',
      String cost = '12.50',
      String opening = '24',
      String barcode = '',
    }) => ProductFormInput(
      name: name,
      barcode: barcode,
      category: '',
      costPrice: cost,
      lowStockThreshold: '5',
      baseUnitName: 'شريط',
      baseUnitSellPrice: '15',
      openingQuantity: opening,
    );

    ProductDraft sentDraft() =>
        verify(() => repository.createProduct(captureAny())).captured.single
            as ProductDraft;

    test('Create_Owner_SendsOpeningAndSaves', () async {
      when(() => repository.createProduct(any()))
          .thenAnswer((_) async => Ok(detail()));
      final c = container()..listen(productFormProvider(null), (_, _) {});

      await c.read(productFormProvider(null).notifier).submit(input());

      expect(c.read(productFormProvider(null)).saved, detail());
      expect(sentDraft().openingQuantity, quantity('24.000'));
    });

    test('Create_Staff_NeverSendsOpening', () async {
      when(() => repository.createProduct(any()))
          .thenAnswer((_) async => Ok(detail()));
      final c = container(session: staffSession)
        ..listen(productFormProvider(null), (_, _) {});

      await c.read(productFormProvider(null).notifier).submit(input());

      expect(sentDraft().openingQuantity, isNull);
    });

    test('Create_LocalIssues_NothingSent', () async {
      final c = container()..listen(productFormProvider(null), (_, _) {});

      await c
          .read(productFormProvider(null).notifier)
          .submit(input(name: ' ', cost: '1.234'));

      final state = c.read(productFormProvider(null));
      expect(state.errors.issues, {
        ProductField.name: ProductFieldIssue.required,
        ProductField.costPrice: ProductFieldIssue.tooManyDecimals,
      });
      verifyNever(() => repository.createProduct(any()));
    });

    test('Create_Submitting_LoadingThenFieldFailure', () async {
      final pending = Completer<Result<Never, Failure>>();
      when(() => repository.createProduct(any()))
          .thenAnswer((_) => pending.future);
      final c = container()..listen(productFormProvider(null), (_, _) {});

      final submit = c.read(productFormProvider(null).notifier).submit(input());
      expect(c.read(productFormProvider(null)).isSubmitting, isTrue);
      pending.complete(Err(conflict(ApiErrorCode.productDuplicateBarcode)));
      await submit;

      final state = c.read(productFormProvider(null));
      expect(state.isSubmitting, isFalse);
      expect(state.errors.fieldFailures.keys, [ProductField.barcode]);
    });

    test('Create_EveryMappedFailure_FieldOrBanner', () async {
      final cases = <(Failure, ProductField?)>[
        (invalidInput(ApiErrorCode.productNameRequired), ProductField.name),
        (
          invalidInput(ApiErrorCode.productUnitNameRequired),
          ProductField.baseUnitName,
        ),
        (conflict(ApiErrorCode.productDuplicateBarcode), ProductField.barcode),
        (invalidInput(ApiErrorCode.precisionTooManyDecimals), null),
        (
          const ForbiddenFailure(
            ApiErrorCode.productOpeningStockOwnerOnly,
            ApiProblemInfo(status: 403),
          ),
          null,
        ),
        (const NetworkFailure(), null),
      ];
      for (final (failure, field) in cases) {
        when(() => repository.createProduct(any()))
            .thenAnswer((_) async => Err(failure));
        final c = container()..listen(productFormProvider(null), (_, _) {});

        await c.read(productFormProvider(null).notifier).submit(input());

        final errors = c.read(productFormProvider(null)).errors;
        if (field == null) {
          expect(errors.banner, failure);
        } else {
          expect(errors.fieldFailures, {field: failure});
          expect(errors.banner, isNull);
        }
      }
    });

    test('Create_ValidationFailed_MessagesUnderFields', () async {
      when(() => repository.createProduct(any())).thenAnswer(
        (_) async => const Err(
          ValidationFailure(
            ApiErrorCode.validationFailed,
            ApiProblemInfo(status: 400),
            fieldErrors: {
              'costPrice': ['Bad price'],
              'unknown': ['?'],
            },
          ),
        ),
      );
      final c = container()..listen(productFormProvider(null), (_, _) {});

      await c.read(productFormProvider(null).notifier).submit(input());

      final errors = c.read(productFormProvider(null)).errors;
      expect(errors.serverErrors, {
        ProductField.costPrice: ['Bad price'],
      });
      expect(errors.banner, isA<ValidationFailure>());
    });

    test('Update_SendsP4_ArchivedConflictInBanner', () async {
      when(() => repository.updateProduct(productId, any()))
          .thenAnswer((_) async => Ok(detail()));
      final c = container()..listen(productFormProvider(productId), (_, _) {});

      await c
          .read(productFormProvider(productId).notifier)
          .submit(input(barcode: '622'));

      final update =
          verify(() => repository.updateProduct(productId, captureAny()))
                  .captured
                  .single
              as ProductUpdate;
      expect(update.barcode, '622');
      expect(update.lowStockThreshold, quantity('5.000'));
      expect(c.read(productFormProvider(productId)).saved, detail());

      final archived = conflict(ApiErrorCode.productArchived);
      when(() => repository.updateProduct(productId, any()))
          .thenAnswer((_) async => Err(archived));
      final c2 = container()..listen(productFormProvider(productId), (_, _) {});
      await c2.read(productFormProvider(productId).notifier).submit(input());
      expect(c2.read(productFormProvider(productId)).errors.banner, archived);
    });
  });

  group('UnitFormNotifier', () {
    const add = UnitFormArgs(productId: productId);
    const edit = UnitFormArgs(productId: productId, unitId: boxUnitId);

    Future<void> save(ProviderContainer c, UnitFormArgs args) => c
        .read(unitFormProvider(args).notifier)
        .save(name: 'علبة', factor: '3', sellPrice: '40', barcode: '');

    test('Add_Ok_Saved', () async {
      when(() => repository.addUnit(productId, any()))
          .thenAnswer((_) async => Ok(boxUnit));
      final c = container()..listen(unitFormProvider(add), (_, _) {});

      await save(c, add);

      expect(c.read(unitFormProvider(add)).outcome, UnitFormOutcome.saved);
      final draft =
          verify(() => repository.addUnit(productId, captureAny()))
                  .captured
                  .single
              as UnitDraft;
      expect(draft.factor.toApi(), '3.000000');
    });

    test('Edit_DuplicateNameAndBarcodeAndFactorFixed_UnderFields', () async {
      for (final (code, field) in [
        (ApiErrorCode.productUnitDuplicateName, ProductField.unitName),
        (ApiErrorCode.productUnitDuplicateBarcode, ProductField.unitBarcode),
        (ApiErrorCode.productUnitBaseUnitFactorFixed, ProductField.unitFactor),
      ]) {
        final failure = code == ApiErrorCode.productUnitBaseUnitFactorFixed
            ? invalidInput(code)
            : conflict(code);
        when(() => repository.updateUnit(productId, boxUnitId, any()))
            .thenAnswer((_) async => Err(failure));
        final c = container()..listen(unitFormProvider(edit), (_, _) {});

        await save(c, edit);

        expect(c.read(unitFormProvider(edit)).errors.fieldFailures, {
          field: failure,
        });
      }
    });

    test('Edit_LocalIssue_NothingSent', () async {
      final c = container()..listen(unitFormProvider(edit), (_, _) {});

      await c
          .read(unitFormProvider(edit).notifier)
          .save(name: '', factor: '0', sellPrice: '1', barcode: '');

      expect(c.read(unitFormProvider(edit)).errors.issues, {
        ProductField.unitName: ProductFieldIssue.required,
        ProductField.unitFactor: ProductFieldIssue.notPositive,
      });
      verifyNever(() => repository.updateUnit(any(), any(), any()));
    });

    test('Delete_Ok_AndInUseBanner', () async {
      when(() => repository.deleteUnit(productId, boxUnitId))
          .thenAnswer((_) async => const Ok(null));
      final c = container()..listen(unitFormProvider(edit), (_, _) {});

      await c.read(unitFormProvider(edit).notifier).delete();
      expect(c.read(unitFormProvider(edit)).outcome, UnitFormOutcome.deleted);

      final inUse = conflict(ApiErrorCode.productUnitInUse);
      when(() => repository.deleteUnit(productId, boxUnitId))
          .thenAnswer((_) async => Err(inUse));
      final c2 = container()..listen(unitFormProvider(edit), (_, _) {});
      await c2.read(unitFormProvider(edit).notifier).delete();
      expect(c2.read(unitFormProvider(edit)).errors.banner, inUse);
    });

    test('Delete_AddForm_DoesNothing', () async {
      final c = container()..listen(unitFormProvider(add), (_, _) {});

      await c.read(unitFormProvider(add).notifier).delete();

      verifyNever(() => repository.deleteUnit(any(), any()));
    });
  });

  group('StockAdjustmentNotifier', () {
    Future<void> submit(ProviderContainer c, {String change = '-2'}) => c
        .read(stockAdjustmentProvider(productId).notifier)
        .submit(quantityChange: change, unitId: boxUnitId, note: 'Expired');

    test('Submit_Ok_MovementAndExactDraft', () async {
      when(() => repository.adjustStock(productId, any()))
          .thenAnswer((_) async => Ok(movement()));
      final c = container()
        ..listen(stockAdjustmentProvider(productId), (_, _) {});

      await submit(c);

      expect(c.read(stockAdjustmentProvider(productId)).movement, movement());
      final draft =
          verify(() => repository.adjustStock(productId, captureAny()))
                  .captured
                  .single
              as StockAdjustmentDraft;
      expect(draft.quantityChange.toApi(), '-2.000');
      expect(draft.unitId, boxUnitId);
    });

    test('Submit_ZeroLocally_NothingSent', () async {
      final c = container()
        ..listen(stockAdjustmentProvider(productId), (_, _) {});

      await submit(c, change: '0');

      expect(c.read(stockAdjustmentProvider(productId)).errors.issues, {
        ProductField.quantityChange: ProductFieldIssue.zero,
      });
      verifyNever(() => repository.adjustStock(any(), any()));
    });

    test('Submit_ServerFailures_FieldOrBanner', () async {
      for (final (failure, field) in <(Failure, ProductField?)>[
        (
          invalidInput(ApiErrorCode.stockZeroChange),
          ProductField.quantityChange,
        ),
        (invalidInput(ApiErrorCode.stockNoteRequired), ProductField.note),
        (
          const NotFoundFailure(
            ApiErrorCode.productUnitNotFound,
            ApiProblemInfo(status: 404),
          ),
          ProductField.stockUnit,
        ),
        (forbidden, null),
        (productNotFound, null),
      ]) {
        when(() => repository.adjustStock(productId, any()))
            .thenAnswer((_) async => Err(failure));
        final c = container()
          ..listen(stockAdjustmentProvider(productId), (_, _) {});

        await submit(c);

        final errors = c.read(stockAdjustmentProvider(productId)).errors;
        expect(
          field == null ? errors.banner : errors.fieldFailures[field],
          failure,
        );
      }
    });
  });

  group('StockCountNotifier', () {
    Future<void> submit(ProviderContainer c, String counted) => c
        .read(stockCountProvider(productId).notifier)
        .submit(countedQuantity: counted, unitId: null);

    test('Submit_ChangedAndUnchanged_Result', () async {
      for (final changed in [true, false]) {
        when(() => repository.recordStockCount(productId, any()))
            .thenAnswer((_) async => Ok(countResult(changed: changed)));
        final c = container()..listen(stockCountProvider(productId), (_, _) {});

        await submit(c, '26');

        expect(
          c.read(stockCountProvider(productId)).result,
          countResult(changed: changed),
        );
      }
      final draft =
          verify(() => repository.recordStockCount(productId, captureAny()))
                  .captured
                  .last
              as StockCountDraft;
      expect(draft.countedQuantity.toApi(), '26.000');
    });

    test('Submit_NegativeLocally_AndServerBanner', () async {
      final c = container()..listen(stockCountProvider(productId), (_, _) {});
      await submit(c, '-1');
      expect(c.read(stockCountProvider(productId)).errors.issues, {
        ProductField.countedQuantity: ProductFieldIssue.negative,
      });

      final precision = invalidInput(ApiErrorCode.precisionOutOfRange);
      when(() => repository.recordStockCount(productId, any()))
          .thenAnswer((_) async => Err(precision));
      await submit(c, '1');
      expect(c.read(stockCountProvider(productId)).errors.banner, precision);
    });
  });
}
