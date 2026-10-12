import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';
import 'package:stockly/features/auth/presentation/providers/sign_out_notifier.dart';

import '../../../helpers/auth_doubles.dart';

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  setUp(() async {
    repository = MockAuthRepository();
    when(() => repository.cachedSession())
        .thenAnswer((_) async => ownerSession);
    when(() => repository.restoreSession())
        .thenAnswer((_) async => Ok(ownerSession));
    container = ProviderContainer.test(
      overrides: authTestOverrides(repository: repository),
    )..listen(signOutProvider, (_, _) {});
    await container.read(authProvider.notifier).restore();
  });

  test('signOut_ShowsProgressThenSignsOut', () async {
    final pending = Completer<void>();
    when(() => repository.logout()).thenAnswer((_) => pending.future);

    final running = container.read(signOutProvider.notifier).signOut();

    expect(container.read(signOutProvider).inProgress, isTrue);
    pending.complete();
    await running;
    expect(container.read(signOutProvider).inProgress, isFalse);
    expect(
      container.read(authProvider).requireValue,
      const AuthState.signedOut(),
    );
  });

  test('signOut_Twice_CallsTheServerOnce', () async {
    final pending = Completer<void>();
    when(() => repository.logout()).thenAnswer((_) => pending.future);

    final first = container.read(signOutProvider.notifier).signOut();
    await container.read(signOutProvider.notifier).signOut();
    pending.complete();
    await first;

    verify(() => repository.logout()).called(1);
  });
}
