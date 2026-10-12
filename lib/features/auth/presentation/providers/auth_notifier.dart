import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/session_restoration.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';
import 'package:stockly/features/auth/presentation/providers/auth_state.dart';

/// Holds the session state. Listens to [SessionSignals] so the network
/// layer can end or suspend the session without depending on this notifier.
final class AuthNotifier extends AsyncNotifier<AuthState> {
  /// Bumped by every sign-in, sign-out and session signal, so a restore
  /// that answers after one of them is dropped. The offline fallback does
  /// not bump it: the running restore still corrects the fallback.
  int _generation = 0;

  @override
  Future<AuthState> build() async {
    final subscription = ref
        .watch(sessionSignalsProvider)
        .stream
        .listen(_onSignal);
    ref.onDispose(subscription.cancel);
    return const AuthState.unknown();
  }

  /// Checks the saved session with the server (the splash at start-up, the
  /// debug panel later). A result that arrives after a sign-in, sign-out or
  /// session signal is dropped; one that arrives after the offline fallback
  /// corrects it.
  Future<void> restore() async {
    await future;
    final generation = _generation;
    final restoration = await ref.read(restoreSessionUseCaseProvider).call();
    if (!ref.mounted || generation != _generation) {
      return;
    }
    _apply(restoration);
  }

  /// The splash maximum passed and the server has not answered: start with
  /// the cached snapshot (design §10.2). [restore] corrects it later.
  Future<void> fallBackToCachedSession() async {
    if (state.value is! AuthUnknown) {
      return;
    }
    final cached = await ref.read(getCachedSessionUseCaseProvider).call();
    if (!ref.mounted || state.value is! AuthUnknown) {
      return;
    }
    state = AsyncData(
      cached == null
          ? const AuthState.signedOut()
          : AuthState.signedIn(cached, offline: true),
    );
  }

  /// Login or register succeeded.
  Future<void> signIn(Session session) async {
    _generation++;
    await ref
        .read(localeProvider.notifier)
        .adoptUserLanguage(session.user.preferredLanguage.name);
    if (ref.mounted) {
      state = AsyncData(AuthState.signedIn(session, offline: false));
    }
  }

  void _apply(SessionRestoration restoration) {
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
    _generation++;
    await ref.read(logoutUseCaseProvider).call();
    state = const AsyncData(AuthState.signedOut());
  }

  void _onSignal(SessionSignal signal) {
    switch (signal) {
      case SessionEndedSignal(:final failure):
        _generation++;
        state = AsyncData(AuthState.signedOut(reason: failure));
      case ShopSuspendedSignal():
        // Without a session (start-up, login) the restore or the form
        // reports the suspension itself.
        if (_session case final session?) {
          _generation++;
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
