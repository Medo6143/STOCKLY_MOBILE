import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/decimal_column.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/core/theme/stockly_colors.dart';
import 'package:stockly/core/widgets/decimal_field.dart';
import 'package:stockly/core/widgets/money_text.dart';
import 'package:stockly/core/widgets/owner_only.dart';
import 'package:stockly/core/widgets/quantity_text.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';

import '../../helpers/auth_doubles.dart';
import '../../helpers/pump_app.dart';

/// The shared number widgets (design §5.4), `OwnerOnly` (design §11),
/// decimal input (design §5.3) and paging state.
void main() {
  testWidgets('MoneyText_LocalizedCurrencyWithLtrIsolate', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(
      tester,
      MoneyText(Money.fromApi('1250.00')),
      locale: locale,
    );

    expect(
      find.text(l10nOf(locale).moneyAmount('\u20661,250.00\u2069')),
      findsOneWidget,
    );
  }, variant: localeVariant);

  testWidgets('QuantityText_NegativeDangerLowWarning', (tester) async {
    final locale = localeVariant.currentValue!;
    await pumpLocalizedApp(
      tester,
      Column(
        children: [
          QuantityText(Quantity.fromApi('-3.000'), unit: 'شريط'),
          QuantityText(Quantity.fromApi('2.500'), isLow: true),
          QuantityText(Quantity.fromApi('4.000'), signed: true),
        ],
      ),
      locale: locale,
    );

    final colors = StocklyColors.light;
    Color? colorOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;
    expect(
      colorOf(l10nOf(locale).quantityWithUnit('\u2066-3\u2069', 'شريط')),
      colors.danger,
    );
    expect(colorOf('\u20662.5\u2069'), colors.warning);
    expect(colorOf('\u2066+4\u2069'), colors.ink);
  }, variant: localeVariant);

  testWidgets('OwnerOnly_HiddenForStaff', (tester) async {
    for (final (session, visible) in [
      (ownerSession, true),
      (staffSession, false),
    ]) {
      await pumpLocalizedApp(
        tester,
        const OwnerOnly(child: Text('owner')),
        locale: localeVariant.currentValue!,
        overrides: [currentSessionProvider.overrideWithValue(session)],
      );
      expect(find.text('owner'), visible ? findsOneWidget : findsNothing);
    }
  }, variant: localeVariant);

  testWidgets('DecimalField_AcceptsDigitsAndSeparatorsOnly', (tester) async {
    final unsigned = TextEditingController();
    final signed = TextEditingController();
    addTearDown(unsigned.dispose);
    addTearDown(signed.dispose);
    await pumpLocalizedApp(
      tester,
      Column(
        children: [
          DecimalField(controller: unsigned, label: 'u', enabled: true),
          DecimalField(
            controller: signed,
            label: 's',
            enabled: true,
            signed: true,
          ),
        ],
      ),
      locale: localeVariant.currentValue!,
    );

    await tester.enterText(find.byType(TextField).first, '-1a٢٫5');
    await tester.enterText(find.byType(TextField).last, '-1a2.5');

    expect(unsigned.text, '1٢٫5');
    expect(signed.text, '-12.5');
    expect(
      tester.widget<TextField>(find.byType(TextField).first).textDirection,
      TextDirection.ltr,
    );
  }, variant: localeVariant);

  test('PagedState_HasMoreAndAppended', () {
    final first = PagedState.first(
      const Paged(items: [1, 2], page: 1, pageSize: 2, totalCount: 3),
    );

    expect(first.hasMore, isTrue);
    final all = first.appended(
      const Paged(items: [3], page: 2, pageSize: 2, totalCount: 3),
    );
    expect(all.items, [1, 2, 3]);
    expect(all.hasMore, isFalse);
  });

  test('DecimalColumn_ExclusiveLimits', () {
    expect(
      DecimalColumn.quantity.fits(Quantity.fromApi('99999999999.999').value),
      isTrue,
    );
    expect(
      DecimalColumn.quantity.fits(Quantity.fromApi('100000000000').value),
      isFalse,
    );
    expect(
      DecimalColumn.money.fits(Money.fromApi('9999999999999999.99').value),
      isTrue,
    );
  });
}
