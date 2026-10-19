import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/app.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/platform/native_splash.dart';
import 'package:stockly/core/router/app_router.dart';
import 'package:stockly/core/router/route_paths.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/core/widgets/form_banner.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/screens/login_screen.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:stockly/features/products/presentation/providers/products_providers.dart';
import 'package:stockly/features/splash/presentation/screens/splash_screen.dart';
import 'package:stockly/features/splash/presentation/widgets/animated_stockly_mark.dart';
import 'package:stockly/features/splash/presentation/widgets/splash_loading_dots.dart';
import 'package:stockly/features/splash/presentation/widgets/stockly_mark_painter.dart';

import '../../helpers/auth_doubles.dart';
import '../../helpers/billing_doubles.dart';
import '../../helpers/dashboard_doubles.dart';
import '../../helpers/fake_app.dart';
import '../../helpers/products_doubles.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_doubles.dart';

const Duration _justBefore = Duration(milliseconds: 1);

/// Design §10 and §11 splash, through the whole app: 4 states × ar/en,
/// the minimum/maximum exit rule, reduce motion, dark smoke.
void main() {
  late FakeNativeSplash nativeSplash;

  setUp(() => nativeSplash = FakeNativeSplash());

  Future<ProviderContainer> start(
    WidgetTester tester, {
    InMemoryTokenStorage? tokens,
    FakeBackendState? state,
    FakeBackendAdapter? adapter,
    MockAuthRepository? repository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...fakeAppOverrides(
            adapter: adapter ?? fakeBackend(state: state),
            tokens: tokens ?? InMemoryTokenStorage(),
            deviceLocale: localeVariant.currentValue!,
          ),
          nativeSplashProvider.overrideWithValue(nativeSplash),
          if (repository != null) ...[
            authRepositoryProvider.overrideWithValue(repository),
            // A mocked session has no real tokens: the home screen behind
            // the splash reads a mocked dashboard, plan and an empty
            // catalogue instead of the backend.
            productsRepositoryProvider.overrideWithValue(emptyCatalog()),
            dashboardRepositoryProvider.overrideWithValue(quietDashboard()),
            billingRepositoryProvider.overrideWithValue(quietBilling()),
          ],
        ],
        retry: (_, _) => null,
        child: const StocklyApp(),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(StocklyApp)));
  }

  String location(ProviderContainer container) => container
      .read(routerProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .toString();

  Future<InMemoryTokenStorage> signedInTokens(
    WidgetTester tester,
    FakeBackendState state,
  ) async {
    final session = await tester.runAsync(
      () => loginOn(fakeBackend(state: state)),
    );
    expect(session, isNotNull);
    return InMemoryTokenStorage(session);
  }

  /// The restore never answers: the session check keeps running.
  MockAuthRepository hangingRepository() {
    final repository = MockAuthRepository();
    when(repository.cachedSession).thenAnswer((_) async => ownerSession);
    when(repository.restoreSession)
        .thenAnswer((_) => Completer<Result<Session, Failure>>().future);
    return repository;
  }

  testWidgets('Loading_MarkWordmarkAndDotsWhileTheCheckRuns', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    final container = await start(tester, repository: hangingRepository());
    await tester.pump(SplashTimings.dotDelays.last);

    expect(location(container), RoutePaths.splash);
    expect(find.byType(AnimatedStocklyMark), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.appName), findsWidgets);
    expect(find.text(l10n.appName), findsOneWidget);
    expect(find.text(l10n.splashTagline), findsOneWidget);
    expect(find.byType(SplashLoadingDots), findsOneWidget);
    expect(nativeSplash.removed, 1);

    await tester.pump(SplashTimings.maximum);
  }, variant: localeVariant);

  testWidgets('Loading_AtTheMaximum_StartsOfflineWithTheCachedSession', (
    tester,
  ) async {
    final container = await start(tester, repository: hangingRepository());

    await tester.pump(SplashTimings.maximum - _justBefore);
    expect(location(container), RoutePaths.splash);

    await tester.pump(_justBefore);
    await tester.pumpAndSettle();

    expect(location(container), RoutePaths.home);
    expect(
      container.read(authProvider).value,
      AuthState.signedIn(ownerSession, offline: true),
    );
  }, variant: localeVariant);

  testWidgets('Empty_NoStoredSession_LoginOnlyAfterTheMinimum', (tester) async {
    final container = await start(tester);

    await tester.pump(SplashTimings.minimum - _justBefore);
    expect(container.read(authProvider).value, isA<AuthSignedOut>());
    expect(location(container), RoutePaths.splash);
    expect(find.byType(SplashLoadingDots), findsNothing);

    await tester.pump(_justBefore);
    await tester.pumpAndSettle();

    expect(location(container), RoutePaths.login);
    expect(find.byType(LoginScreen), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_Offline_StartsSignedInOffline', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await signedInTokens(tester, state);
    final adapter = fakeBackend(state: state)..controls.offline = true;

    final container = await start(tester, tokens: tokens, adapter: adapter);
    await tester.pump(SplashTimings.minimum);
    await tester.pumpAndSettle();

    expect(location(container), RoutePaths.home);
    final auth = container.read(authProvider).value! as AuthSignedIn;
    expect(auth.offline, isTrue);
  }, variant: localeVariant);

  testWidgets('Error_SessionRejected_LoginSaysTheSessionEnded', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    final tokens = InMemoryTokenStorage(storedSession());

    final container = await start(tester, tokens: tokens);
    await tester.pump(SplashTimings.minimum);
    await tester.pumpAndSettle();

    expect(location(container), RoutePaths.login);
    expect(tokens.session, isNull);
    expect(
      find.descendant(
        of: find.byType(FormBanner),
        matching: find.text(l10n.errorSessionEnded),
      ),
      findsOneWidget,
    );
  }, variant: localeVariant);

  testWidgets('Error_ShopSuspended_GoesToSuspended', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await signedInTokens(tester, state);
    state.shops.single.status = FakeShopStatuses.suspended;

    final container = await start(tester, tokens: tokens, state: state);
    await tester.pump(SplashTimings.minimum);
    await tester.pumpAndSettle();

    expect(location(container), RoutePaths.suspended);
  }, variant: localeVariant);

  testWidgets('Data_SignedIn_GoesHomeAfterTheMinimum', (tester) async {
    final state = FakeSeed.pharmacy(FakeClock().now());
    final tokens = await signedInTokens(tester, state);

    final container = await start(tester, tokens: tokens, state: state);
    await tester.pump(SplashTimings.minimum - _justBefore);
    expect(container.read(authProvider).value, isA<AuthSignedIn>());
    expect(location(container), RoutePaths.splash);

    await tester.pump(_justBefore);
    await tester.pumpAndSettle();

    expect(location(container), RoutePaths.home);
    expect(find.byType(SplashScreen), findsNothing);
  }, variant: localeVariant);

  testWidgets('ReduceMotion_FinalFrameAtOnceAndNoMinimum', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final l10n = l10nOf(localeVariant.currentValue!);

    final container = await start(tester, repository: hangingRepository());

    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(AnimatedStocklyMark),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((paint.painter! as StocklyMarkPainter).progress, 1);
    for (final text in [l10n.appName, l10n.splashTagline]) {
      final fades = tester.widgetList<FadeTransition>(
        find.ancestor(
          of: find.text(text),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fades, isNotEmpty);
      for (final fade in fades) {
        expect(fade.opacity.value, 1, reason: text);
      }
    }
    final dots = tester.widgetList<Opacity>(
      find.descendant(
        of: find.byType(SplashLoadingDots),
        matching: find.byType(Opacity),
      ),
    );
    expect(dots.map((d) => d.opacity), everyElement(0.25));
    expect(SchedulerBinding.instance.transientCallbackCount, 0);

    await tester.pump(SplashTimings.maximum);
    await tester.pumpAndSettle();
    expect(location(container), RoutePaths.home);
  }, variant: localeVariant);

  testWidgets('ReduceMotion_LeavesAsSoonAsTheSessionIsResolved', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final container = await start(tester);
    await tester.pump();
    await tester.pump();

    expect(location(container), RoutePaths.login);
    await tester.pump(SplashTimings.maximum);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await start(tester, repository: hangingRepository());
    await tester.pump(SplashTimings.controller);

    expect(
      Theme.of(tester.element(find.byType(SplashScreen))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    await tester.pump(SplashTimings.maximum);
  }, variant: localeVariant);
}
