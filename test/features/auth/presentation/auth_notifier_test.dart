import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/features/auth/data/models/session_mapper.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/session_restoration.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';

import '../../../helpers/test_doubles.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

final Session _owner = storedSession().toEntity();
final Session _staff = storedSession(role: 'Staff').toEntity();
const SessionEndedFailure _ended = SessionEndedFailure(
  ApiErrorCode.authRefreshTokenReused,
  ApiProblemInfo(status: 401),
);
const ShopSuspendedFailure _suspendedFailure = ShopSuspendedFailure(
  ApiErrorCode.shopSuspended,
  ApiProblemInfo(status: 403),
);

void main() {
  late _MockAuthRepository repository;
  late SessionSignals signals;
  late ProviderContainer container;

  setUp(() async {
    repository = _MockAuthRepository();
    signals = SessionSignals();
    container = ProviderContainer.test(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        sessionSignalsProvider.overrideWithValue(signals),
      ],
    )..listen(authProvider, (_, _) {});
    await container.read(authProvider.future);
  });

  /// Makes the repository produce [restoration] through the real
  /// `RestoreSessionUseCase`.
  Future<AuthState> restoreWith(SessionRestoration restoration) async {
    final (
      Session? cached,
      Result<Session, Failure>? server,
    ) = switch (restoration) {
      RestorationNone() => (null, null),
      RestorationActive(:final session) => (session, Ok(session)),
      RestorationOffline(:final session) => (
        session,
        const Err(NetworkFailure()),
      ),
      RestorationEnded(:final reason) => (_owner, Err(reason)),
      RestorationSuspended(:final session) => (
        session,
        const Err(_suspendedFailure),
      ),
    };
    when(() => repository.cachedSession()).thenAnswer((_) async => cached);
    if (server != null) {
      when(() => repository.restoreSession()).thenAnswer((_) async => server);
    }
    await container.read(authProvider.notifier).restore();
    return container.read(authProvider).requireValue;
  }

  test('build_StartsUnknown', () {
    expect(
      container.read(authProvider).requireValue,
      const AuthState.unknown(),
    );
    expect(container.read(currentSessionProvider), isNull);
    expect(container.read(isOwnerProvider), isFalse);
  });

  test('restore_MapsEveryRestoration', () async {
    expect(
      await restoreWith(const SessionRestoration.none()),
      const AuthState.signedOut(),
    );
    expect(
      await restoreWith(SessionRestoration.active(_owner)),
      AuthState.signedIn(_owner, offline: false),
    );
    expect(container.read(currentSessionProvider), _owner);
    expect(container.read(isOwnerProvider), isTrue);
    expect(
      await restoreWith(SessionRestoration.offline(_staff)),
      AuthState.signedIn(_staff, offline: true),
    );
    expect(container.read(isOwnerProvider), isFalse);
    expect(
      await restoreWith(const SessionRestoration.ended(_ended)),
      const AuthState.signedOut(reason: _ended),
    );
    expect(
      await restoreWith(SessionRestoration.suspended(_owner)),
      AuthState.suspended(_owner),
    );
    expect(container.read(currentSessionProvider), _owner);
  });

  test('logout_SignsOut', () async {
    await restoreWith(SessionRestoration.active(_owner));
    when(() => repository.logout()).thenAnswer((_) async {
      return;
    });

    await container.read(authProvider.notifier).logout();

    expect(
      container.read(authProvider).requireValue,
      const AuthState.signedOut(),
    );
    verify(() => repository.logout()).called(1);
  });

  test('sessionEndedSignal_SignsOutWithReason', () async {
    await restoreWith(SessionRestoration.active(_owner));

    signals.sessionEnded(_ended);
    await pumpEventQueue();

    expect(
      container.read(authProvider).requireValue,
      const AuthState.signedOut(reason: _ended),
    );
  });

  test('shopSuspendedSignal_WhenSignedIn_Suspends', () async {
    await restoreWith(SessionRestoration.active(_owner));

    signals.shopSuspended(_suspendedFailure);
    await pumpEventQueue();

    expect(
      container.read(authProvider).requireValue,
      AuthState.suspended(_owner),
    );
  });

  test('shopSuspendedSignal_WhenSignedOut_Ignored', () async {
    await restoreWith(const SessionRestoration.none());

    signals.shopSuspended(_suspendedFailure);
    await pumpEventQueue();

    expect(
      container.read(authProvider).requireValue,
      const AuthState.signedOut(),
    );
  });
}
