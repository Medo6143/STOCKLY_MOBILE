import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/sales/domain/entities/pending_sale.dart';
import 'package:stockly/features/sales/domain/entities/sale_date_range.dart';
import 'package:stockly/features/sales/domain/entities/sale_list_item.dart';
import 'package:stockly/features/sales/presentation/providers/pending_sale_providers.dart';
import 'package:stockly/features/sales/presentation/providers/sale_detail_notifier.dart';
import 'package:stockly/features/sales/presentation/providers/sale_list_notifier.dart';
import 'package:stockly/features/sales/presentation/providers/sales_providers.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/sales_doubles.dart';
import '../../../helpers/test_doubles.dart';

/// `SaleListNotifier`, `SaleDetailNotifier` and `pendingSaleProvider` with
/// a mocked repository.
void main() {
  late MockSalesRepository sales;
  late FakeClock clock;

  setUpAll(registerSaleFallbacks);

  setUp(() {
    sales = MockSalesRepository();
    clock = FakeClock(DateTime.utc(2026, 10, 12, 9));
  });

  ProviderContainer container({bool signedIn = true}) {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        salesRepositoryProvider.overrideWithValue(sales),
        currentSessionProvider.overrideWithValue(
          signedIn ? ownerSession : null,
        ),
        clockProvider.overrideWithValue(clock),
        appLoggerProvider.overrideWithValue(const NoopLogger()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Paged<SaleListItem> salesPage(
    List<SaleListItem> items, {
    int page = 1,
    int total = 1,
  }) => Paged(items: items, page: page, pageSize: 20, totalCount: total);

  group('SaleListNotifier', () {
    test('Today_FromTheLocalMidnight', () async {
      when(
        () => sales.getSales(
          from: any(named: 'from'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => Ok(salesPage([saleListItem()])));
      final c = container();

      final state = await c.read(saleListProvider(SaleDateRange.today).future);

      expect(state.items, [saleListItem()]);
      verify(
        () => sales.getSales(
          from: SaleDateRange.today.fromUtc(clock.now()),
          page: 1,
          pageSize: 20,
        ),
      ).called(1);
    });

    test('All_NoBoundAndLoadMore', () async {
      when(
        () => sales.getSales(
          from: null,
          page: 1,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => Ok(salesPage([saleListItem()], total: 21)));
      when(
        () => sales.getSales(
          from: null,
          page: 2,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          salesPage(
            [saleListItem(id: '0192f0a0-6c1e-7b3a-9d2e-5a1e00000002')],
            page: 2,
            total: 21,
          ),
        ),
      );
      final c = container();
      final provider = saleListProvider(SaleDateRange.all);
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);
      await c.read(provider.future);

      await c.read(provider.notifier).loadMore();

      expect(c.read(provider).value?.items, hasLength(2));
    });

    test('Error_IsTheFailure', () async {
      when(
        () => sales.getSales(
          from: any(named: 'from'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final c = container();

      await expectLater(
        c.read(saleListProvider(SaleDateRange.lastSevenDays).future),
        throwsA(const NetworkFailure()),
      );
    });
  });

  group('SaleDetailNotifier', () {
    test('Data', () async {
      when(() => sales.getSale(saleId)).thenAnswer((_) async => Ok(sale()));
      final c = container();

      expect(await c.read(saleDetailProvider(saleId).future), sale());
    });

    test('NotFound_IsTheFailure', () async {
      when(() => sales.getSale(saleId))
          .thenAnswer((_) async => const Err(saleNotFound));
      final c = container();

      await expectLater(
        c.read(saleDetailProvider(saleId).future),
        throwsA(saleNotFound),
      );
    });
  });

  group('pendingSaleProvider', () {
    test('ScopedToTheSessionShop', () async {
      final rows = StreamController<PendingSale?>();
      addTearDown(rows.close);
      when(() => sales.watchPendingSale(ownerSession.shop.id))
          .thenAnswer((_) => rows.stream);
      final c = container();
      final sub = c.listen(pendingSaleProvider, (_, _) {});
      addTearDown(sub.close);

      rows.add(pendingSale());
      await Future<void>.delayed(Duration.zero);

      expect(c.read(pendingSaleProvider).value, pendingSale());
    });

    test('NoSession_Nothing', () async {
      final c = container(signedIn: false);
      final sub = c.listen(pendingSaleProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await c.read(pendingSaleProvider.future), isNull);
      verifyNever(() => sales.watchPendingSale(any()));
    });
  });
}
