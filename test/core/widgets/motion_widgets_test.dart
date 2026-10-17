import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/router/stockly_pages.dart';
import 'package:stockly/core/theme/app_theme.dart';
import 'package:stockly/core/theme/stockly_curves.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/widgets/action_tile.dart';
import 'package:stockly/core/widgets/animated_count.dart';
import 'package:stockly/core/widgets/animated_money_text.dart';
import 'package:stockly/core/widgets/entrance.dart';
import 'package:stockly/core/widgets/entrance_scope.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/core/widgets/success_check.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

import '../../helpers/pump_app.dart';

/// Design-refresh brief §5: counters, staggered entrance, shimmer, page
/// transitions and reduce motion (rule 39).
void main() {
  const durations = StocklyDurations.standard;

  Locale locale() => localeVariant.currentValue!;

  int ticking(WidgetTester tester) => tester.binding.transientCallbackCount;

  group('AnimatedMoneyText', () {
    test('AtStep_EveryStepIsExactMoney_TheLastIsTheValue', () {
      final money = Money.fromApi('1250.50');
      var previous = Money.zero;
      for (var step = 0; step <= MotionGeometry.counterSteps; step++) {
        final shown = AnimatedMoneyText.atStep(money, step);
        expect(shown.value.scale, lessThanOrEqualTo(Money.scale));
        expect(shown.compareTo(previous), greaterThanOrEqualTo(0));
        expect(shown.compareTo(money), lessThanOrEqualTo(0));
        previous = shown;
      }
      expect(AnimatedMoneyText.atStep(money, 0), Money.zero);
      expect(
        AnimatedMoneyText.atStep(money, MotionGeometry.counterSteps),
        money,
      );
    });

    testWidgets('CountsUp_EndsOnTheExactValue', (tester) async {
      final l10n = l10nOf(locale());
      final value = l10n.moneyAmount(ltrIsolate('1,250.50'));
      await pumpLocalizedApp(
        tester,
        AnimatedMoneyText(Money.fromApi('1250.50')),
        locale: locale(),
      );

      await tester.pump(durations.counter ~/ 4);
      expect(find.text(value), findsNothing);
      expect(ticking(tester), greaterThan(0));

      await tester.pumpAndSettle();
      expect(find.text(value), findsOneWidget);
    }, variant: localeVariant);

    testWidgets('ReduceMotion_ShowsTheValueAtOnce_NoTicking', (tester) async {
      final l10n = l10nOf(locale());
      await pumpLocalizedApp(
        tester,
        AnimatedMoneyText(Money.fromApi('1250.50')),
        locale: locale(),
        disableAnimations: true,
      );

      expect(
        find.text(l10n.moneyAmount(ltrIsolate('1,250.50'))),
        findsOneWidget,
      );
      expect(ticking(tester), 0);
    }, variant: localeVariant);
  });

  group('AnimatedCount', () {
    const style = TextStyle();

    testWidgets('CountsUp_EndsOnTheExactValue', (tester) async {
      await pumpLocalizedApp(
        tester,
        const AnimatedCount(31, style: style),
        locale: locale(),
      );

      await tester.pump(durations.counter ~/ 4);
      expect(find.text(ltrIsolate('31')), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text(ltrIsolate('31')), findsOneWidget);
    }, variant: localeVariant);

    testWidgets('ReduceMotion_NoTicking', (tester) async {
      await pumpLocalizedApp(
        tester,
        const AnimatedCount(31, style: style),
        locale: locale(),
        disableAnimations: true,
      );

      expect(find.text(ltrIsolate('31')), findsOneWidget);
      expect(ticking(tester), 0);
    }, variant: localeVariant);
  });

  group('Entrance', () {
    Widget list(List<String> items) => EntranceScope(
      child: ListView(
        children: [
          for (final (index, item) in items.indexed)
            Entrance(key: ValueKey(item), index: index, child: Text(item)),
        ],
      ),
    );

    Finder fading(String item) =>
        find.ancestor(of: find.text(item), matching: find.byType(Opacity));

    testWidgets('Scope_OnlyTheFirstFrameStaggers', (tester) async {
      final items = ValueNotifier(['a', 'b']);
      addTearDown(items.dispose);
      await pumpLocalizedApp(
        tester,
        ValueListenableBuilder(
          valueListenable: items,
          builder: (context, value, _) => list(value),
        ),
        locale: locale(),
      );

      expect(fading('a'), findsOneWidget);
      expect(fading('b'), findsOneWidget);
      expect(ticking(tester), greaterThan(0));
      await tester.pumpAndSettle();

      items.value = ['a', 'b', 'c'];
      await tester.pump();

      expect(find.text('c'), findsOneWidget);
      expect(fading('c'), findsNothing);
      expect(ticking(tester), 0);
    }, variant: localeVariant);

    testWidgets('ReduceMotion_FinalFrameNoTicking', (tester) async {
      await pumpLocalizedApp(
        tester,
        list(['a', 'b']),
        locale: locale(),
        disableAnimations: true,
      );

      expect(fading('a'), findsNothing);
      expect(ticking(tester), 0);
    }, variant: localeVariant);
  });

  group('Loading skeleton', () {
    testWidgets('Shimmers', (tester) async {
      await pumpLocalizedApp(tester, const LoadingState(), locale: locale());

      expect(ticking(tester), greaterThan(0));
      expect(
        find.bySemanticsLabel(l10nOf(locale()).commonLoading),
        findsOneWidget,
      );
    }, variant: localeVariant);

    testWidgets('ReduceMotion_StandsStill', (tester) async {
      for (final shape in LoadingShape.values) {
        await pumpLocalizedApp(
          tester,
          LoadingState(shape: shape),
          locale: locale(),
          disableAnimations: true,
        );

        expect(ticking(tester), 0, reason: shape.name);
        expect(tester.takeException(), isNull, reason: shape.name);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }, variant: localeVariant);
  });

  group('SuccessCheck', () {
    testWidgets('Draws_ThenStops', (tester) async {
      await pumpLocalizedApp(tester, const SuccessCheck(), locale: locale());

      expect(ticking(tester), greaterThan(0));
      await tester.pumpAndSettle();
      expect(ticking(tester), 0);
      expect(find.byType(SuccessCheck), findsOneWidget);
    }, variant: localeVariant);

    testWidgets('ReduceMotion_NoTicking', (tester) async {
      await pumpLocalizedApp(
        tester,
        const SuccessCheck(),
        locale: locale(),
        disableAnimations: true,
      );

      expect(ticking(tester), 0);
    }, variant: localeVariant);
  });

  group('ActionTile', () {
    testWidgets('Chevron_PointsToTheEndEdge', (tester) async {
      await pumpLocalizedApp(
        tester,
        ActionTile(
          icon: Icons.settings_outlined,
          title: l10nOf(locale()).navSettings,
          onTap: () {},
        ),
        locale: locale(),
      );

      final chevron = find.byIcon(Icons.chevron_right_rounded);
      expect(tester.widget<Icon>(chevron).icon?.matchTextDirection, isTrue);
      final mirrored = find.descendant(
        of: chevron,
        matching: find.byType(Transform),
      );
      final arabic = locale().languageCode == 'ar';
      expect(mirrored, arabic ? findsOneWidget : findsNothing);
    }, variant: localeVariant);
  });

  group('StocklyPages', () {
    test('SlideStart_FromTheEndEdge', () {
      expect(
        StocklyPages.slideStart(TextDirection.ltr),
        MotionGeometry.pushSlide,
      );
      expect(
        StocklyPages.slideStart(TextDirection.rtl),
        -MotionGeometry.pushSlide,
      );
    });

    Future<GoRouter> pumpPush(
      WidgetTester tester, {
      bool disableAnimations = false,
    }) async {
      tester.view
        ..physicalSize = const Size(1000, 2000)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('home')),
            routes: [
              GoRoute(
                path: 'next',
                pageBuilder: (context, state) => StocklyPages.push(
                  context,
                  state,
                  const Scaffold(body: SizedBox.expand(key: ValueKey('next'))),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: locale(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
        ),
      );
      return router;
    }

    testWidgets('Push_SlidesInFromTheEndEdge_MirroredInRtl', (tester) async {
      final router = await pumpPush(tester);

      router.go('/next');
      await tester.pump();
      await tester.pump(durations.page ~/ 4);

      final x = tester.getTopLeft(find.byKey(const ValueKey('next'))).dx;
      if (locale().languageCode == 'ar') {
        expect(x, lessThan(0));
      } else {
        expect(x, greaterThan(0));
      }
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(const ValueKey('next'))).dx, 0);
    }, variant: localeVariant);

    testWidgets('Push_ReduceMotion_Instant', (tester) async {
      final router = await pumpPush(tester, disableAnimations: true);

      router.go('/next');
      await tester.pump();

      expect(tester.getTopLeft(find.byKey(const ValueKey('next'))).dx, 0);
      expect(ticking(tester), 0);
    }, variant: localeVariant);
  });
}
