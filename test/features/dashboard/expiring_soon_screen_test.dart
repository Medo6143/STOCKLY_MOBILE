import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/router/route_names.dart';
import 'package:stockly/core/theme/stockly_colors.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/dashboard/domain/entities/expiring_item.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/dashboard/presentation/screens/expiring_soon_screen.dart';
import 'package:stockly/features/dashboard/presentation/widgets/expiring_item_tile.dart';

import '../../helpers/dashboard_doubles.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/routed_screen.dart';

/// Design §11 ExpiringSoonScreen: 4 states × ar/en, the window chips, the
/// invoice link and dark.
void main() {
  late MockDashboardRepository repository;

  setUp(() => repository = MockDashboardRepository());

  void answer(
    Future<Result<Paged<ExpiringItem>, Failure>> Function() result, {
    int? days,
  }) => when(
    () => repository.getExpiringSoon(
      days: days ?? any(named: 'days'),
      page: any(named: 'page'),
      pageSize: any(named: 'pageSize'),
    ),
  ).thenAnswer((_) => result());

  Future<void> pump(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    int days = ExpiringSoonWindow.defaultDays,
  }) => pumpRoutedScreen(
    tester,
    ExpiringSoonScreen(initialDays: days),
    themeMode: themeMode,
    overrides: [dashboardRepositoryProvider.overrideWithValue(repository)],
  );

  testWidgets('Loading', (tester) async {
    final pending = Completer<Result<Paged<ExpiringItem>, Failure>>();
    answer(() => pending.future);
    await pump(tester);
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(routedL10n().expiringTitle), findsOneWidget);
    expect(find.text(routedL10n().expiringHint), findsOneWidget);
    pending.complete(Ok(dashboardPage<ExpiringItem>(const [])));
    await tester.pumpAndSettle();
  }, variant: localeVariant);

  testWidgets('Empty_NothingExpiresInTheWindow', (tester) async {
    answer(() async => Ok(dashboardPage<ExpiringItem>(const [])));
    await pump(tester, days: 30);
    await tester.pumpAndSettle();

    final l = routedL10n();
    expect(find.text(l.expiringEmptyTitle(ltrIsolate('30'))), findsOneWidget);
    expect(find.text(l.expiringEmptyBody), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_RetryLoads', (tester) async {
    answer(() async => const Err(NetworkFailure()));
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    answer(() async => Ok(dashboardPage([expiringItem()])));
    await tester.tap(find.text(routedL10n().commonRetry));
    await tester.pumpAndSettle();
    expect(find.byType(ExpiringItemTile), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_LineDetailsAndInvoiceLink', (tester) async {
    answer(() async => Ok(dashboardPage([expiringItem()])));
    await pump(tester);
    await tester.pumpAndSettle();

    final l = routedL10n();
    final language = localeVariant.currentValue!.languageCode;
    expect(find.text('بروفين 400'), findsOneWidget);
    expect(
      find.text(
        l.expiringExpiresOn(
          ltrIsolate(DateFormatter.date(expiringItem().expiryDate, language)),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(l.expiringBatch(ltrIsolate('BR-40'))), findsOneWidget);
    expect(find.text(l.expiringInStock), findsOneWidget);
    expectStartSide(tester, find.byIcon(Icons.event_busy_rounded));

    await tester.tap(find.text('بروفين 400'));
    await tester.pumpAndSettle();
    expect(routedTo(RouteNames.invoiceDetail), findsOneWidget);
    expect(find.text('/invoice/$expiringInvoiceId'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_ExpiredLineMarkedWithADangerChip', (tester) async {
    answer(
      () async => Ok(
        dashboardPage([
          expiringItem(
            name: 'كونجستال',
            expiry: const CalendarDate(2026, 10, 1),
          ),
          expiringItem(),
        ]),
      ),
    );
    await pump(tester);
    await tester.pumpAndSettle();

    final chip = find.text(routedL10n().expiringExpiredChip);
    expect(chip, findsOneWidget);
    expect(
      find.ancestor(of: chip, matching: find.byType(ExpiringItemTile)),
      findsOneWidget,
    );
    final expired = tester.widget<ExpiringItemTile>(
      find.ancestor(of: chip, matching: find.byType(ExpiringItemTile)),
    );
    expect(expired.item.productName, 'كونجستال');
    expect(expired.expired, isTrue);
    final style = tester.widget<Text>(chip).style;
    final colors = Theme.of(tester.element(chip)).extension<StocklyColors>()!;
    expect(style?.color, colors.danger);
    final soon = tester
        .widgetList<ExpiringItemTile>(find.byType(ExpiringItemTile))
        .last;
    expect(soon.expired, isFalse);
  }, variant: localeVariant);

  testWidgets('Chips_ChangeTheWindow', (tester) async {
    answer(() async => Ok(dashboardPage([expiringItem()])));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(
      find.text(routedL10n().expiringDaysChip(ltrIsolate('90'))),
    );
    await tester.pumpAndSettle();

    verify(
      () => repository.getExpiringSoon(
        days: 90,
        page: 1,
        pageSize: ExpiringSoonWindow.pageSize,
      ),
    ).called(1);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    answer(() async => Ok(dashboardPage([expiringItem()])));
    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byType(ExpiringItemTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
