import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/domain/usecases/get_dashboard_summary_use_case.dart';
import 'package:stockly/features/dashboard/domain/usecases/get_expiring_soon_use_case.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';
import 'package:stockly/features/dashboard/presentation/providers/expiring_soon_notifier.dart';

import '../../helpers/dashboard_doubles.dart';

/// Dashboard use cases and notifiers (D1, D2) with a mocked repository.
void main() {
  late MockDashboardRepository repository;

  setUp(() => repository = MockDashboardRepository());

  ProviderContainer container() {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        dashboardRepositoryProvider.overrideWithValue(repository),
        appLoggerProvider.overrideWithValue(const NoopLogger()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void answerPage(int days, int page, {int total = 1}) =>
      when(
        () => repository.getExpiringSoon(
          days: days,
          page: page,
          pageSize: ExpiringSoonWindow.pageSize,
        ),
      ).thenAnswer(
        (_) async =>
            Ok(dashboardPage([expiringItem()], page: page, totalCount: total)),
      );

  group('use cases', () {
    test('Summary_Ok', () async {
      when(repository.getSummary).thenAnswer((_) async => Ok(summary()));

      final result = await GetDashboardSummaryUseCase(repository).call();

      expect((result as Ok).value, summary());
    });

    test('Summary_Failure', () async {
      when(repository.getSummary)
          .thenAnswer((_) async => const Err(NetworkFailure()));

      final result = await GetDashboardSummaryUseCase(repository).call();

      expect((result as Err).failure, const NetworkFailure());
    });

    test('ExpiringSoon_DaysAndPageSize', () async {
      answerPage(30, 2);

      await GetExpiringSoonUseCase(repository).call(30, page: 2);

      verify(
        () => repository.getExpiringSoon(
          days: 30,
          page: 2,
          pageSize: ExpiringSoonWindow.pageSize,
        ),
      ).called(1);
    });
  });

  test('ExpiringItem_ExpiredBeforeToday', () {
    const today = CalendarDate(2026, 10, 12);
    expect(
      expiringItem(expiry: const CalendarDate(2026, 10, 11)).isExpiredOn(today),
      isTrue,
    );
    expect(expiringItem(expiry: today).isExpiredOn(today), isFalse);
    expect(expiringItem().isExpiredOn(today), isFalse);
  });

  test('Summary_NewShopHasNoProducts', () {
    expect(summary(productCount: 0).isNewShop, isTrue);
    expect(summary().isNewShop, isFalse);
  });

  group('DashboardSummaryNotifier', () {
    test('Data', () async {
      when(repository.getSummary).thenAnswer((_) async => Ok(summary()));

      expect(
        await container().read(dashboardSummaryProvider.future),
        summary(),
      );
    });

    test('Error_IsTheFailure', () async {
      when(repository.getSummary)
          .thenAnswer((_) async => const Err(TimeoutFailure()));

      await expectLater(
        container().read(dashboardSummaryProvider.future),
        throwsA(const TimeoutFailure()),
      );
    });

    test('Invalidate_Reloads', () async {
      when(repository.getSummary).thenAnswer((_) async => Ok(summary()));
      final c = container();
      final sub = c.listen(dashboardSummaryProvider, (_, _) {});
      addTearDown(sub.close);
      await c.read(dashboardSummaryProvider.future);

      when(repository.getSummary)
          .thenAnswer((_) async => Ok(summary(salesCount: 4)));
      c.invalidate(dashboardSummaryProvider);

      final next = await c.read(dashboardSummaryProvider.future);
      expect(next.todaySales.count, 4);
    });
  });

  group('ExpiringSoonNotifier', () {
    test('FirstPageThenMore', () async {
      answerPage(60, 1, total: 21);
      answerPage(60, 2, total: 21);
      final c = container();
      final provider = expiringSoonProvider(60);
      final sub = c.listen(provider, (_, _) {});
      addTearDown(sub.close);

      final first = await c.read(provider.future);
      expect(first.items, [expiringItem()]);
      await c.read(provider.notifier).loadMore();

      expect(c.read(provider).value?.items, hasLength(2));
    });

    test('Empty', () async {
      when(
        () => repository.getExpiringSoon(
          days: 90,
          page: 1,
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => Ok(dashboardPage<ExpiringItem>(const [])));

      final state = await container().read(expiringSoonProvider(90).future);

      expect(state.items, isEmpty);
    });

    test('Error_IsTheFailure', () async {
      when(
        () => repository.getExpiringSoon(
          days: any(named: 'days'),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      await expectLater(
        container().read(expiringSoonProvider(30).future),
        throwsA(const NetworkFailure()),
      );
    });
  });
}
