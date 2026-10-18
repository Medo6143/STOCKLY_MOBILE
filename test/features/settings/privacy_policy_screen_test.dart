import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/widgets/leading_badge.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/section_card.dart';
import 'package:stockly/features/settings/presentation/screens/privacy_policy_screen.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../helpers/pump_app.dart';

/// Brief mobile-6 §3.4: the static privacy policy in ar/en, RTL, dark and
/// reduce motion.
void main() {
  Future<void> pumpPolicy(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    bool disableAnimations = false,
  }) async {
    tester.view
      ..physicalSize = const Size(1080, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpLocalizedApp(
      tester,
      const PrivacyPolicyScreen(),
      locale: localeVariant.currentValue!,
      themeMode: themeMode,
      disableAnimations: disableAnimations,
    );
  }

  AppLocalizations l10n() => l10nOf(localeVariant.currentValue!);

  testWidgets('Data_EverySectionFromTheArbFiles', (tester) async {
    await pumpPolicy(tester);
    await tester.pumpAndSettle();

    final l = l10n();
    for (final text in [
      l.privacyPolicyTitle,
      l.privacyIntro,
      l.privacyCollectedTitle,
      l.privacyCollectedAccount,
      l.privacyCollectedShop,
      l.privacyCollectedPhotos,
      l.privacyCollectedSales,
      l.privacyProcessorsTitle,
      l.privacyProcessorsBody,
      l.privacyNeverTitle,
      l.privacyNeverBody,
      l.privacyDeviceTitle,
      l.privacyDeviceBody,
      l.privacyDeletionTitle,
      l.privacyDeletionBody(ltrIsolate(PrivacyContact.email)),
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byType(SectionCard), findsNWidgets(5));
  }, variant: localeVariant);

  testWidgets('Data_StatesTheRetentionAndTheProcessor', (tester) async {
    await pumpPolicy(tester);
    await tester.pumpAndSettle();

    final isArabic = localeVariant.currentValue!.languageCode == 'ar';
    expect(
      find.textContaining(isArabic ? '٩٠ يوم' : '90 days'),
      findsOneWidget,
    );
    expect(find.textContaining('OpenRouter'), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Rtl_BadgeOnTheReadingSide', (tester) async {
    await pumpPolicy(tester);
    await tester.pumpAndSettle();

    final width = tester.view.physicalSize.width;
    final badge = tester.getCenter(find.byType(LeadingBadge)).dx;
    final direction = Directionality.of(
      tester.element(find.byType(PrivacyPolicyScreen)),
    );
    if (localeVariant.currentValue!.languageCode == 'ar') {
      expect(direction, TextDirection.rtl);
      expect(badge, greaterThan(width / 2));
    } else {
      expect(direction, TextDirection.ltr);
      expect(badge, lessThan(width / 2));
    }
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pumpPolicy(tester, themeMode: ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(LeadingBadge))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);

  testWidgets('ReduceMotion_FinalFrameNoTicking', (tester) async {
    await pumpPolicy(tester, disableAnimations: true);
    await tester.pump();

    expect(find.text(l10n().privacyNeverBody), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  }, variant: localeVariant);
}
