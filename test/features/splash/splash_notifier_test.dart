import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/splash/presentation/providers/splash_notifier.dart';
import 'package:stockly/features/splash/presentation/providers/splash_state.dart';

import '../../helpers/auth_doubles.dart';

const Duration _justBefore = Duration(milliseconds: 1);

/// Design §10.2 exit rule. `testWidgets` gives fake time for the timers.
void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockAuthRepository();
    container = ProviderContainer.test(
      overrides: authTestOverrides(repository: repository),
    )..listen(splashProvider, (_, _) {});
  });

  SplashState splash() => container.read(splashProvider);

  test('build_NotStarted_NotFinished', () {
    expect(splash(), const SplashState());
    expect(splash().finished, isFalse);
  });

  testWidgets('start_FinishesAtTheMinimum', (tester) async {
    container.read(splashProvider.notifier).start(reducedMotion: false);

    await tester.pump(SplashTimings.minimum - _justBefore);
    expect(splash().finished, isFalse);

    await tester.pump(_justBefore);
    expect(splash().minimumElapsed, isTrue);
    expect(splash().finished, isTrue);
    await tester.pump(SplashTimings.maximum);
  });

  testWidgets('start_ReducedMotion_NoMinimum', (tester) async {
    container.read(splashProvider.notifier).start(reducedMotion: true);

    expect(splash().finished, isTrue);
    await tester.pump(SplashTimings.maximum);
  });

  testWidgets('start_Twice_KeepsTheFirstTimers', (tester) async {
    final notifier = container.read(splashProvider.notifier)
      ..start(reducedMotion: false);
    await tester.pump(SplashTimings.minimum - _justBefore);

    notifier.start(reducedMotion: true);

    expect(splash().reducedMotion, isFalse);
    expect(splash().finished, isFalse);
    await tester.pump(SplashTimings.maximum);
  });

  testWidgets('maximum_SessionStillUnknown_StartsWithTheCachedSession', (
    tester,
  ) async {
    when(() => repository.cachedSession())
        .thenAnswer((_) async => ownerSession);
    when(() => repository.restoreSession())
        .thenAnswer((_) => Completer<Result<Session, Failure>>().future);
    await container.read(authProvider.future);
    unawaited(container.read(authProvider.notifier).restore());
    container.read(splashProvider.notifier).start(reducedMotion: false);

    await tester.pump(SplashTimings.maximum - _justBefore);
    expect(container.read(authProvider).value, const AuthState.unknown());

    await tester.pump(_justBefore);
    await tester.pump();

    expect(splash().maximumElapsed, isTrue);
    expect(
      container.read(authProvider).value,
      AuthState.signedIn(ownerSession, offline: true),
    );
  });

  testWidgets('maximum_SessionResolved_Unchanged', (tester) async {
    when(() => repository.cachedSession()).thenAnswer((_) async => null);
    await container.read(authProvider.future);
    await container.read(authProvider.notifier).restore();
    container.read(splashProvider.notifier).start(reducedMotion: false);

    await tester.pump(SplashTimings.maximum);
    await tester.pump();

    expect(container.read(authProvider).value, const AuthState.signedOut());
    verify(() => repository.cachedSession()).called(1);
  });
}
