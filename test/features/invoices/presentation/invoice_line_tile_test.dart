import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/status_pill.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/presentation/widgets/invoice_line_tile.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../../helpers/invoices_doubles.dart';
import '../../../helpers/pump_app.dart';

/// Brief mobile-6 §3.3: a trigram match under 90% asks the user to check
/// it, with the percent, in both languages.
void main() {
  InvoiceLineDraft line({
    String? confidence,
    LineProductChoice choice = const LineProductChoice.existing(
      productId: productId,
      productUnitId: boxUnitId,
      productName: 'بنادول اكسترا',
      unitName: 'علبة',
    ),
  }) => InvoiceLineDraft(
    lineNo: 2,
    rawName: 'بندول اكسترا',
    choice: choice,
    quantity: Quantity.fromApi('3.000'),
    unitPrice: Money.fromApi('36.00'),
    matchConfidence: confidence == null
        ? null
        : MatchConfidence.fromApi(confidence),
  );

  Future<void> pumpTile(
    WidgetTester tester,
    InvoiceLineDraft line, {
    ThemeMode themeMode = ThemeMode.light,
  }) => pumpLocalizedApp(
    tester,
    ListView(children: [InvoiceLineTile(line: line)]),
    locale: localeVariant.currentValue!,
    themeMode: themeMode,
  );

  AppLocalizations l10n() => l10nOf(localeVariant.currentValue!);

  Finder checkPill(String percent) =>
      find.text(l10n().invoiceLineCheckMatch(ltrIsolate(percent)));

  testWidgets('LowConfidence_CheckThisMatchWithThePercent', (tester) async {
    await pumpTile(tester, line(confidence: '0.85'));
    await tester.pumpAndSettle();

    expect(checkPill('85'), findsOneWidget);
    final pill = tester.widget<StatusPill>(find.byType(StatusPill));
    expect(pill.tone, PillTone.warning);
    // The percent is shown once, in the hint, not again in the details.
    expect(
      find.textContaining(l10n().invoiceLineConfidence(ltrIsolate('85'))),
      findsNothing,
    );
  }, variant: localeVariant);

  testWidgets('JustBelowThreshold_StillAsks', (tester) async {
    await pumpTile(tester, line(confidence: '0.89'));
    await tester.pumpAndSettle();

    expect(checkPill('89'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('AtThreshold_PlainPercentNoHint', (tester) async {
    await pumpTile(tester, line(confidence: '0.90'));
    await tester.pumpAndSettle();

    expect(find.byType(StatusPill), findsNothing);
    expect(
      find.textContaining(l10n().invoiceLineConfidence(ltrIsolate('90'))),
      findsOneWidget,
    );
  }, variant: localeVariant);

  testWidgets('NoConfidence_NoHint', (tester) async {
    await pumpTile(tester, line());
    await tester.pumpAndSettle();

    expect(find.byType(StatusPill), findsNothing);
  }, variant: localeVariant);

  testWidgets('UnresolvedLine_NoHint', (tester) async {
    await pumpTile(
      tester,
      line(confidence: '0.40', choice: const LineProductChoice.unresolved()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(StatusPill), findsNothing);
    expect(find.text(l10n().invoiceLineUnresolved), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Rtl_HintStartsOnTheReadingSide', (tester) async {
    await pumpTile(tester, line(confidence: '0.70'));
    await tester.pumpAndSettle();

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final pill = tester.getRect(find.byType(StatusPill));
    if (localeVariant.currentValue!.languageCode == 'ar') {
      expect(pill.right, greaterThan(width / 2));
    } else {
      expect(pill.left, lessThan(width / 2));
    }
  }, variant: localeVariant);

  testWidgets('Dark_HintRendersWithDarkTokens', (tester) async {
    await pumpTile(tester, line(confidence: '0.70'), themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(checkPill('70'), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(StatusPill))).brightness,
      Brightness.dark,
    );
  }, variant: localeVariant);
}
