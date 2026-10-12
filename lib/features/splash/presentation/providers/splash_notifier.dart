import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/theme/stockly_durations.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';
import 'package:stockly/features/splash/presentation/providers/splash_state.dart';

/// Drives the splash exit rule (design §10.2): the splash leaves when the
/// minimum has passed (or motion is reduced) and the session is resolved,
/// and at the latest at the maximum, when the cached session is used if
/// the server has not answered yet. Kept alive: the router reads it.
final class SplashNotifier extends Notifier<SplashState> {
  Timer? _minimum;
  Timer? _maximum;

  @override
  SplashState build() {
    ref.onDispose(() {
      _minimum?.cancel();
      _maximum?.cancel();
    });
    return const SplashState();
  }

  /// Starts the timers once, when the splash is first shown.
  void start({required bool reducedMotion}) {
    if (state.started) {
      return;
    }
    state = SplashState(started: true, reducedMotion: reducedMotion);
    if (!reducedMotion) {
      _minimum = Timer(SplashTimings.minimum, () {
        state = state.copyWith(minimumElapsed: true);
      });
    }
    _maximum = Timer(SplashTimings.maximum, () {
      state = state.copyWith(maximumElapsed: true);
      unawaited(ref.read(authProvider.notifier).fallBackToCachedSession());
    });
  }
}

final splashProvider = NotifierProvider<SplashNotifier, SplashState>(
  SplashNotifier.new,
);
