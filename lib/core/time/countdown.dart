import 'dart:async';

import 'package:stockly/core/time/clock.dart';

/// Counts down to a moment, once per [tick], reading the time from [Clock]
/// so a long pause (app in the background) never makes it run late.
final class Countdown {
  new(this._clock, {this.tick = defaultTick});

  static const Duration defaultTick = Duration(seconds: 1);

  final Clock _clock;
  final Duration tick;
  Timer? _timer;

  /// Calls [onTick] now with [total], then every [tick] with the time left,
  /// and a last time with [Duration.zero]. Replaces a running countdown.
  void start(Duration total, void Function(Duration remaining) onTick) {
    cancel();
    final end = _clock.now().add(total);
    onTick(total);
    if (total <= Duration.zero) {
      return;
    }
    _timer = Timer.periodic(tick, (timer) {
      final remaining = end.difference(_clock.now());
      if (remaining <= Duration.zero) {
        timer.cancel();
        onTick(Duration.zero);
      } else {
        onTick(remaining);
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
