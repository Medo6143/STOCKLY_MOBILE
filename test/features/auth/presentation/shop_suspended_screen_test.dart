import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/widgets/loading_state.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/screens/shop_suspended_screen.dart';

import '../../../helpers/auth_doubles.dart';
import '../../../helpers/pump_app.dart';

/// Design §11 suspended screen: 4 states × ar/en, dark smoke.
void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  Future<ProviderContainer> pumpSuspended(
    WidgetTester tester, {
    Session? session,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await pumpLocalizedApp(
      tester,
      const ShopSuspendedScreen(),
      locale: localeVariant.currentValue!,
      themeMode: themeMode,
      overrides: [
        ...authTestOverrides(
          repository: repository,
          deviceLocale: localeVariant.currentValue!,
        ),
        currentSessionProvider.overrideWithValue(session),
      ],
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(ShopSuspendedScreen)),
    );
  }

  Finder signOutButton() => find.byWidgetPredicate((w) => w is FilledButton);

  testWidgets('Data_ExplanationShopNameAndSignOut', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    await pumpSuspended(tester, session: ownerSession);

    expect(find.text(l10n.suspendedTitle), findsOneWidget);
    expect(find.text(ownerSession.shop.name), findsOneWidget);
    expect(find.text(l10n.suspendedBody), findsOneWidget);
    expect(find.text(l10n.authSignOut), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Empty_NotApplicable_TheExplanationIsAlwaysShown', (
    tester,
  ) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    await pumpSuspended(tester, session: staffSession);

    expect(find.text(l10n.suspendedBody), findsOneWidget);
    expect(find.text(l10n.authSignOut), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Loading_SigningOutShowsTheSpinner', (tester) async {
    final l10n = l10nOf(localeVariant.currentValue!);
    final pending = Completer<void>();
    when(() => repository.logout()).thenAnswer((_) => pending.future);
    await pumpSuspended(tester, session: ownerSession);

    await tester.tap(signOutButton());
    await tester.pump();

    expect(
      find.descendant(
        of: signOutButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(signOutButton()).onPressed, isNull);
    expect(find.text(l10n.suspendedBody), findsOneWidget);
    pending.complete();
    await tester.pump();
  }, variant: localeVariant);

  testWidgets('Loading_SessionGone_LoadingState', (tester) async {
    await pumpSuspended(tester);

    expect(find.byType(LoadingState), findsOneWidget);
  }, variant: localeVariant);

  testWidgets('Error_NoneBlocksSignOut_ServerUnreachableStillSignsOut', (
    tester,
  ) async {
    // The repository clears the device even when A4 fails (2a); sign out
    // never shows an error.
    when(() => repository.logout()).thenAnswer((_) async {});
    final container = await pumpSuspended(tester, session: ownerSession);

    await tester.tap(signOutButton());
    await tester.pump();

    expect(container.read(authProvider).value, const AuthState.signedOut());
    verify(() => repository.logout()).called(1);
  }, variant: localeVariant);

  testWidgets('Dark_RendersWithDarkTokens', (tester) async {
    await pumpSuspended(
      tester,
      session: ownerSession,
      themeMode: ThemeMode.dark,
    );

    expect(
      Theme.of(tester.element(find.byType(ShopSuspendedScreen))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
  }, variant: localeVariant);
}
