import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/usecases/confirm_invoice_use_case.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/dashboard_doubles.dart';
import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/products_doubles.dart' as products;

/// Design §11 Sprint 4 confirm (I5): `ConfirmInvoiceUseCase` and the
/// review notifier's save-if-dirty-then-confirm flow.
void main() {
  late MockInvoicesRepository invoices;
  late products.MockProductsRepository catalog;
  late MockDashboardRepository dashboard;

  final resolvedInvoice = invoiceDetail(items: [invoiceItem()]);
  final confirmed = invoiceDetail(
    status: InvoiceStatus.confirmed,
    items: [invoiceItem()],
  );

  setUpAll(() {
    registerInvoiceFallbacks();
    products.registerProductFallbacks();
  });

  setUp(() {
    invoices = MockInvoicesRepository();
    catalog = products.emptyCatalog();
    dashboard = quietDashboard();
    when(() => invoices.getInvoice(invoiceId))
        .thenAnswer((_) async => Ok(resolvedInvoice));
  });

  ProviderContainer container() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        invoicesRepositoryProvider.overrideWithValue(invoices),
        productsRepositoryProvider.overrideWithValue(catalog),
        dashboardRepositoryProvider.overrideWithValue(dashboard),
        scanQueueRepositoryProvider.overrideWithValue(EmptyScanQueue()),
        currentSessionProvider.overrideWithValue(ownerSession),
        appLoggerProvider.overrideWithValue(const NoopLogger()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<(ProviderContainer, InvoiceReviewNotifier)> review() async {
    final c = container()..listen(invoiceReviewProvider(invoiceId), (_, _) {});
    await c.read(invoiceReviewProvider(invoiceId).future);
    return (c, c.read(invoiceReviewProvider(invoiceId).notifier));
  }

  InvoiceReviewState stateOf(ProviderContainer c) =>
      c.read(invoiceReviewProvider(invoiceId)).requireValue;

  void answerConfirm(Future<Result<InvoiceDetail, Failure>> Function() r) =>
      when(() => invoices.confirm(invoiceId)).thenAnswer((_) => r());

  group('ConfirmInvoiceUseCase', () {
    test('Ok_TheConfirmedInvoice', () async {
      answerConfirm(() async => Ok(confirmed));

      final result = await ConfirmInvoiceUseCase(invoices).call(invoiceId);

      expect((result as Ok).value, confirmed);
    });

    test('NotConfirmable_TheFailure', () async {
      const failure = ConflictFailure(
        ApiErrorCode.invoiceNotConfirmable,
        ApiProblemInfo(status: HttpStatus.conflict),
      );
      answerConfirm(() async => const Err(failure));

      final result = await ConfirmInvoiceUseCase(invoices).call(invoiceId);

      expect((result as Err).failure, failure);
    });
  });

  group('InvoiceReviewNotifier.confirm', () {
    test(
      'Clean_ConfirmsWithoutSaving_InvalidatesProductsAndDashboard',
      () async {
        answerConfirm(() async => Ok(confirmed));
        final (c, notifier) = await review();
        final products = c.listen(
          productListProvider(const ProductQuery()),
          (_, _) {},
        );
        final summary = c.listen(dashboardSummaryProvider, (_, _) {});
        addTearDown(products.close);
        addTearDown(summary.close);
        await c.read(dashboardSummaryProvider.future);
        await c.read(productListProvider(const ProductQuery()).future);

        await notifier.confirm();

        verifyNever(() => invoices.saveItems(any(), any()));
        verify(() => invoices.confirm(invoiceId)).called(1);
        final state = stateOf(c);
        expect(state.invoice.status, InvoiceStatus.confirmed);
        expect(state.isReadOnly, isTrue);
        expect(state.isConfirming, isFalse);
        expect(state.confirmedCount, 1);
        await c.read(dashboardSummaryProvider.future);
        await c.read(productListProvider(const ProductQuery()).future);
        verify(dashboard.getSummary).called(2);
        verify(
          () => catalog.getProducts(
            any(),
            page: any(named: 'page'),
            pageSize: any(named: 'pageSize'),
          ),
        ).called(2);
      },
    );

    test('Dirty_SavesFirstThenConfirms', () async {
      final saved = invoiceDetail(items: [invoiceItem()], warnings: const []);
      when(() => invoices.saveItems(any(), any()))
          .thenAnswer((_) async => Ok(saved));
      answerConfirm(() async => Ok(confirmed));
      final (c, notifier) = await review();
      notifier.setSupplierName('مورد جديد');

      await notifier.confirm();

      verifyInOrder([
        () => invoices.saveItems(invoiceId, any()),
        () => invoices.confirm(invoiceId),
      ]);
      expect(stateOf(c).invoice.status, InvoiceStatus.confirmed);
      expect(stateOf(c).savedCount, 1);
    });

    test('Dirty_SaveFails_NothingConfirmed', () async {
      when(() => invoices.saveItems(any(), any()))
          .thenAnswer((_) async => const Err(NetworkFailure()));
      final (c, notifier) = await review();
      notifier.setSupplierName('مورد جديد');

      await notifier.confirm();

      verifyNever(() => invoices.confirm(any()));
      expect(stateOf(c).failure, const NetworkFailure());
      expect(stateOf(c).isDirty, isTrue);
    });

    test('UnresolvedLine_FlaggedOnTheDeviceAndNothingSent', () async {
      when(() => invoices.getInvoice(invoiceId))
          .thenAnswer((_) async => Ok(invoiceDetail()));
      final (c, notifier) = await review();

      await notifier.confirm();

      expect(stateOf(c).lineErrors, {2});
      verifyNever(() => invoices.confirm(any()));
    });

    test('ConfirmingState_WhileI5Runs', () async {
      final pending = Completer<Result<InvoiceDetail, Failure>>();
      answerConfirm(() => pending.future);
      final (c, notifier) = await review();

      final done = notifier.confirm();
      expect(stateOf(c).isConfirming, isTrue);
      expect(stateOf(c).canSave, isFalse);
      notifier.setSupplierName('x');
      expect(stateOf(c).isDirty, isFalse);

      pending.complete(Ok(confirmed));
      await done;
      expect(stateOf(c).isConfirming, isFalse);
    });

    test('NetworkFailure_BannerAndRetryIsSafe', () async {
      answerConfirm(() async => const Err(TimeoutFailure()));
      final (c, notifier) = await review();

      await notifier.confirm();
      expect(stateOf(c).failure, const TimeoutFailure());
      expect(stateOf(c).invoice.status, InvoiceStatus.needsReview);

      answerConfirm(() async => Ok(confirmed));
      await notifier.confirm();
      expect(stateOf(c).invoice.status, InvoiceStatus.confirmed);
      expect(stateOf(c).failure, isNull);
      verify(() => invoices.confirm(invoiceId)).called(2);
    });

    test('ServerLineProductRequired_HighlightsUnresolved', () async {
      answerConfirm(
        () async => Err(
          InvalidInputFailure(
            ApiErrorCode.invoiceLineProductRequired,
            problem(HttpStatus.badRequest),
          ),
        ),
      );
      final (c, notifier) = await review();

      await notifier.confirm();

      expect(
        (stateOf(c).failure! as ApiFailure).code,
        ApiErrorCode.invoiceLineProductRequired,
      );
      expect(stateOf(c).confirmedCount, 0);
    });

    test('NotConfirmable_ReloadsTheInvoice', () async {
      const failure = ConflictFailure(
        ApiErrorCode.invoiceNotConfirmable,
        ApiProblemInfo(status: HttpStatus.conflict),
      );
      answerConfirm(() async => const Err(failure));
      final (c, notifier) = await review();
      when(() => invoices.getInvoice(invoiceId)).thenAnswer(
        (_) async => Ok(invoiceDetail(status: InvoiceStatus.failed)),
      );

      await notifier.confirm();

      expect(stateOf(c).isReadOnly, isTrue);
      expect(stateOf(c).failure, failure);
      expect(stateOf(c).invoice.status, InvoiceStatus.failed);
    });

    test('NotFound_Banner', () async {
      answerConfirm(() async => const Err(invoiceNotFound));
      final (c, notifier) = await review();

      await notifier.confirm();

      expect(stateOf(c).failure, invoiceNotFound);
      expect(stateOf(c).draft, InvoiceDraft.fromDetail(resolvedInvoice));
    });
  });
}
