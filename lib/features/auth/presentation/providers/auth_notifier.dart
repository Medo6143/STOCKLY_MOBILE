import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/session_restoration.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';

/// Holds the session state. Listens to [SessionSignals] so the network
/// layer can end or suspend the session without depending on this notifier.
final class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final subscription = ref
        .watch(sessionSignalsProvider)
        .stream
        .listen(_onSignal);
    ref.onDispose(subscription.cancel);
    return const AuthState.unknown();
  }

  /// Checks the saved session at start-up (called by the splash).
  Future<void> restore() async {
    await future;
    final restoration = await ref.read(restoreSessionUseCaseProvider).call();
    state = AsyncData(switch (restoration) {
      RestorationNone() => const AuthState.signedOut(),
      RestorationActive(:final session) => AuthState.signedIn(
        session,
        offline: false,
      ),
      RestorationOffline(:final session) => AuthState.signedIn(
        session,
        offline: true,
      ),
      RestorationEnded(:final reason) => AuthState.signedOut(reason: reason),
      RestorationSuspended(:final session) => AuthState.suspended(session),
    });
  }

  /// Signs out. The local session is cleared even when the server cannot be
  /// reached.
  Future<void> logout() async {
    await ref.read(logoutUseCaseProvider).call();
    state = const AsyncData(AuthState.signedOut());
  }

  void _onSignal(SessionSignal signal) {
    switch (signal) {
      case SessionEndedSignal(:final failure):
        state = AsyncData(AuthState.signedOut(reason: failure));
      case ShopSuspendedSignal():
        if (_session case final session?) {
          state = AsyncData(AuthState.suspended(session));
        }
    }
  }

  Session? get _session => switch (state.value) {
    AuthSignedIn(:final session) || AuthSuspended(:final session) => session,
    _ => null,
  };
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// The signed-in (or suspended) session, or `null`.
final currentSessionProvider = Provider<Session?>(
  (ref) => switch (ref.watch(authProvider).value) {
    AuthSignedIn(:final session) || AuthSuspended(:final session) => session,
    _ => null,
  },
);

/// `true` when the current user is the shop's Owner.
final isOwnerProvider = Provider<bool>(
  (ref) => ref.watch(currentSessionProvider)?.shop.role == ShopRole.owner,
);
