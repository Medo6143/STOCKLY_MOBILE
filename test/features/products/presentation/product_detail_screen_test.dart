import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/widgets/error_state.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/products/domain/entities/product_detail.dart';
import 'package:stockly/features/products/presentation/screens/product_detail_screen.dart';
import 'package:stockly/features/products/presentation/widgets/product_hero_tags.dart';
import 'package:stockly/features/products/presentation/widgets/unit_list_tile.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/products_doubles.dart';
import '../../../helpers/pump_app.dart';
import 'screen_harness.dart';

/// Design §11 `ProductDetailScreen`: 4 states × ar/en, Owner vs Staff
/// actions, archive, dark.
void main() {
  late MockProductsRepository repository;

  setUpAll(registerProductFallbacks);
  setUp(() => repository = MockProductsRepository());

  Future<void> pump(
    WidgetTester tester, {
    Session? session,
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpProductScreen(
    tester,
    const ProductDetailScreen(productId: productId),
    repository: repository,
    session: session,
    themeMode: themeMode,
  );

  void stub(FutureOr<Result<ProductDetail, Failure>> Function() answer) =>
      when(() => repository.getProduct(productId))
          .thenAnswer((_) async => await answer());

  Finder button(String label) => find.text(label);

  testWidgets('Loading_WhileP2Runs', (tester) async {
    final pending = Completer<Result<ProductDetail, Failure>>();
    when(() => repository.getProduct(productId))
        .thenAnswer((_) => pending.future);

    await pump(tester);

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(l10n().productsDetailTitle), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_NotApplicable_TheBaseUnitIsAlwaysListed', (tester) async {
    stub(() => Ok(detail(units: [baseUnit])));

    await pump(tester);
    await tester.pump();

    expect(find.byType(UnitListTile), findsOneWidget);
    expect(find.text(l10n().productsDetailBaseUnit), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_NotFound_MessageAndBack', (tester) async {
    stub(() => const Err(productNotFound));

    await pump(tester);
    await tester.pump();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text(l10n().errorProductNotFound), findsOneWidget);
    expect(find.text(l10n().commonBack), findsOneWidget);
    expect(find.text(l10n().commonRetry), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Data_Owner_AllFactsUnitsAndActions', (tester) async {
    stub(() => Ok(detail(qty: '4.000', isLowStock: true)));

    await pump(tester);
    await tester.pump();

    final l = l10n();
    for (final text in [
      'بنادول اكسترا',
      'مسكنات',
      l.productsDetailQuantity,
      l.productsDetailCostPrice,
      l.productsDetailSellPrice,
      l.productsDetailThreshold,
      l.productsDetailUnitsHeader,
      l.productsLowStockBadge,
      l.quantityWithUnit('\u20664\u2069', 'شريط'),
      l.moneyAmount('\u206612.50\u2069'),
      l.productsUnitFactor('علبة', '\u20663\u2069', 'شريط'),
    ]) {
      expect(find.text(text), findsWidgets, reason: text);
    }
    expect(find.byType(UnitListTile), findsNWidgets(2));
    for (final label in [
      l.productsDetailEdit,
      l.productsDetailMovements,
      l.productsDetailAdjust,
      l.productsDetailCount,
      l.productsDetailArchive,
      l.productsDetailAddUnit,
    ]) {
      expect(button(label), findsOneWidget, reason: label);
    }
  }, variant: localeVariant);

  testWidgets('Hero_SameTagsAsTheListRow', (tester) async {
    stub(() => Ok(detail()));

    await pump(tester);
    await tester.pump();

    for (final part in ProductHeroPart.values) {
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == productHeroTag(part, productId),
        ),
        findsOneWidget,
        reason: part.name,
      );
    }
  }, variant: localeVariant);

  testWidgets('Data_Staff_NoOwnerActions', (tester) async {
    stub(() => Ok(detail()));

    await pump(tester, session: staffSession);
    await tester.pump();

    final l = l10n();
    expect(button(l.productsDetailEdit), findsOneWidget);
    expect(button(l.productsDetailMovements), findsOneWidget);
    expect(button(l.productsDetailAddUnit), findsOneWidget);
    expect(button(l.productsDetailAdjust), findsNothing);
    expect(button(l.productsDetailCount), findsNothing);
    expect(button(l.productsDetailArchive), findsNothing);
  }, variant: localeVariant);

  testWidgets('Data_Archived_ReadOnlyWithNotice', (tester) async {
    stub(() => Ok(detail(isArchived: true)));

    await pump(tester);
    await tester.pump();

    final l = l10n();
    expect(find.text(l.productsDetailArchivedNotice), findsOneWidget);
    expect(find.text(l.productsArchivedChip), findsOneWidget);
    expect(button(l.productsDetailEdit), findsNothing);
    expect(button(l.productsDetailArchive), findsNothing);
    expect(button(l.productsDetailAddUnit), findsNothing);
    expect(button(l.productsDetailAdjust), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Archive_ConfirmThenArchivedSnackbar', (tester) async {
    var archived = false;
    when(() => repository.getProduct(productId))
        .thenAnswer((_) async => Ok(detail(isArchived: archived)));
    when(() => repository.archiveProduct(productId)).thenAnswer((_) async {
      archived = true;
      return const Ok(null);
    });
    await pump(tester);
    await tester.pump();

    await tester.tap(button(l10n().productsDetailArchive));
    await tester.pumpAndSettle();
    expect(find.text(l10n().productsArchiveDialogTitle), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    verify(() => repository.archiveProduct(productId)).called(1);
    expect(find.text(l10n().productsArchived), findsOneWidget);
    expect(find.text(l10n().productsDetailArchivedNotice), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Archive_Forbidden_ShowsTheFailure', (tester) async {
    stub(() => Ok(detail()));
    when(() => repository.archiveProduct(productId))
        .thenAnswer((_) async => const Err(forbidden));
    await pump(tester);
    await tester.pump();

    await tester.tap(button(l10n().productsDetailArchive));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n().errorAuthForbidden), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Archive_Cancel_NothingSent', (tester) async {
    stub(() => Ok(detail()));
    await pump(tester);
    await tester.pump();

    await tester.tap(button(l10n().productsDetailArchive));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n().commonCancel));
    await tester.pumpAndSettle();

    verifyNever(() => repository.archiveProduct(any()));
  }, variant: localeVariant);

  testWidgets('Dark_DataRenders', (tester) async {
    stub(() => Ok(detail()));

    await pump(tester, themeMode: ThemeMode.dark);
    await tester.pump();

    expect(
      Theme.of(tester.element(find.byType(UnitListTile).first)).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
