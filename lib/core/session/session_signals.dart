import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/failure.dart';

/// A session event raised by the network layer. Interceptors publish here
/// instead of depending on `authProvider` (that would be a cycle).
@immutable
sealed class SessionSignal {
  const new();
}

/// The server rejected the session: sign out.
final class SessionEndedSignal extends SessionSignal {
  const new(this.failure);

  final SessionEndedFailure failure;
}

/// The shop was suspended: only logout is possible.
final class ShopSuspendedSignal extends SessionSignal {
  const new(this.failure);

  final ShopSuspendedFailure failure;
}

final class SessionSignals {
  final StreamController<SessionSignal> _controller =
      StreamController<SessionSignal>.broadcast();

  Stream<SessionSignal> get stream => _controller.stream;

  void sessionEnded(SessionEndedFailure failure) =>
      _controller.add(SessionEndedSignal(failure));

  void shopSuspended(ShopSuspendedFailure failure) =>
      _controller.add(ShopSuspendedSignal(failure));

  Future<void> close() => _controller.close();
}

final sessionSignalsProvider = Provider<SessionSignals>((ref) {
  final signals = SessionSignals();
  ref.onDispose(signals.close);
  return signals;
});
