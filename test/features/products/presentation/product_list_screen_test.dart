import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/products/domain/entities/product_list_item.dart';
import 'package:stockly/features/products/domain/entities/product_query.dart';
import 'package:stockly/features/products/presentation/screens/product_list_screen.dart';
import 'package:stockly/features/products/presentation/widgets/product_list_tile.dart';

import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'screen_harness.dart';

/// Design §11 `ProductListScreen`: 4 states × ar/en, search, filters,
/// paging, RTL and dark.
void main() {
  late MockProductsRepository repository;

  setUpAll(registerProductFallbacks);
  setUp(() => repository = MockProductsRepository());

  void stub(
    FutureOr<Result<Paged<ProductListItem>, Failure>> Function(
      ProductQuery query,
      int page,
    )
    answer,
  ) =>
      when(
        () => repository.getProducts(
          any(),
          page: any(named: 'page'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer(
        (i) async => await answer(
          i.positionalArguments.first as ProductQuery,
          i.namedArguments[#page] as int,
        ),
      );

  final items = [
    listItem(id: 'a'),
    listItem(id: 'b', name: 'نوفالجين', qty: '-3.000', isLowStock: true),
    listItem(id: 'c', name: 'فيفادول', isArchived: true),
  ];

  Future<void> pump(
    WidgetTester tester, {
    ProductQuery query = const ProductQuery(),
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpProductScreen(
    tester,
    ProductListScreen(initialQuery: query),
    repository: repository,
    themeMode: themeMode,
  );

  testWidgets('Loading_FirstPage', (tester) async {
    final pending = Completer<Result<Paged<ProductListItem>, Failure>>();
    stub((_, _) => pending.future);

    await pump(tester);

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().productsListTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_NoProducts_AddAction', (tester) async {
    stub((_, _) => Ok(page<ProductListItem>(const [])));

    await pump(tester);
    await tester.pump();

    expect(find.text(l10n().productsListEmptyTitle), findsOneWidget);
    expect(find.text(l10n().productsListEmptyBody), findsOneWidget);
    expect(find.text(l10n().productsListAdd), findsNWidgets(2));
  }, variant: localeVariant);

  testWidgets('Empty_Search_NoResultsForTheTerm', (tester) async {
    stub(
      (query, _) => Ok(
        query.search.isEmpty ? page(items) : page<ProductListItem>(const []),
      ),
    );
    await pump(tester);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump(StocklyDurations.standard.searchDebounce);
    await tester.pump();

    expect(find.text(l10n().productsListNoResultsTitle('xyz')), findsOneWidget);
    verify(
      () => repository.getProducts(
        const ProductQuery(search: 'xyz'),
        page: 1,
        pageSize: 20,
      ),
    ).called(1);

    await tester.tap(find.byTooltip(l10n().productsSearchClear));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProductListTile), findsNWidgets(3));
  }, variant: localeVariant);

  testWidgets('Empty_LowStockFilter_NoLowStockText', (tester) async {
    stub((_, _) => Ok(page<ProductListItem>(const [])));

    await pump(tester, query: const ProductQuery(lowStock: true));
    await tester.pump();

    expect(find.text(l10n().productsListNoLowStockTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_ShowsMessageAndRetry', (tester) async {
    var calls = 0;
    stub((_, _) {
      calls++;
      return calls == 1 ? const Err(NetworkFailure()) : Ok(page(items));
    });

    await pump(tester);
    await tester.pump();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorNetwork), findsOneWidget);
    await tester.tap(find.text(l10n().commonRetry));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProductListTile), findsNWidgets(3));
  }, variant: localeVariant);

  testWidgets('Data_RowsWithBadgesAndLtrNumbers', (tester) async {
    stub((_, _) => Ok(page(items)));

    await pump(tester);
    await tester.pump();

    for (final item in items) {
      expect(find.text(item.name), findsOneWidget);
    }
    expect(find.text(l10n().productsLowStockBadge), findsOneWidget);
    expect(find.text(l10n().productsArchivedChip), findsOneWidget);
    expect(
      find.text(l10n().quantityWithUnit('\u2066-3\u2069', 'شريط')),
      findsOneWidget,
    );
    expect(
      find.text(l10n().moneyAmount('\u206615.00\u2069')),
      findsNWidgets(3),
    );
  }, variant: localeVariant);

  testWidgets('Data_FilterChips_ReloadWithTheFilter', (tester) async {
    stub((_, _) => Ok(page(items)));
    await pump(tester);
    await tester.pump();

    await tester.tap(find.text(l10n().productsFilterLowStock));
    await tester.pump();
    await tester.tap(find.text(l10n().productsFilterArchived));
    await tester.pump();

    verify(
      () => repository.getProducts(
        const ProductQuery(lowStock: true),
        page: 1,
        pageSize: 20,
      ),
    ).called(1);
    verify(
      () => repository.getProducts(
        const ProductQuery(lowStock: true, includeArchived: true),
        page: 1,
        pageSize: 20,
      ),
    ).called(1);
  }, variant: localeVariant);

  testWidgets('Data_NextPageFails_InlineErrorThenRetryLoadsIt', (tester) async {
    var failNext = true;
    stub((_, p) {
      if (p == 1) {
        return Ok(page([items.first], totalCount: 21));
      }
      if (failNext) {
        failNext = false;
        return const Err(TimeoutFailure());
      }
      return Ok(page([items[1]], page: 2, totalCount: 21));
    });

    await pump(tester);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n().commonLoadMoreError), findsOneWidget);
    expect(find.text(l10n().errorTimeout), findsOneWidget);
    await tester.tap(find.text(l10n().commonRetry));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ProductListTile), findsNWidgets(2));
  }, variant: localeVariant);

  testWidgets('Rtl_RowsAndSearchFollowTheLanguage', (tester) async {
    stub((_, _) => Ok(page(items)));

    await pump(tester);
    await tester.pump();

    expectLeading(tester, find.text(items.first.name));
    expectLeading(tester, find.byIcon(Icons.search_rounded));
  }, variant: localeVariant);

  testWidgets('Dark_DataRenders', (tester) async {
    stub((_, _) => Ok(page(items)));

    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pump();

    expect(
      Theme.of(tester.element(find.byType(ProductListTile).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
