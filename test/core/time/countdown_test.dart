import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/time/countdown.dart';

import '../../helpers/test_doubles.dart';

/// `testWidgets` runs in fake time: `tester.pump(d)` fires the timers.
void main() {
  Future<void> elapse(WidgetTester tester, FakeClock clock, Duration by) {
    clock.advance(by);
    return tester.pump(by);
  }

  testWidgets('start_TicksEverySecondFromTheClock_EndsAtZero', (tester) async {
    final clock = FakeClock();
    final ticks = <Duration>[];
    Countdown(clock).start(const Duration(seconds: 3), ticks.add);

    for (var i = 0; i < 4; i++) {
      await elapse(tester, clock, const Duration(seconds: 1));
    }

    expect(ticks, const [
      Duration(seconds: 3),
      Duration(seconds: 2),
      Duration(seconds: 1),
      Duration.zero,
    ]);
    await elapse(tester, clock, const Duration(seconds: 5));
    expect(ticks, hasLength(4));
  });

  testWidgets('start_ClockJumpsAhead_EndsAtTheNextTick', (tester) async {
    final clock = FakeClock();
    final ticks = <Duration>[];
    Countdown(clock).start(const Duration(minutes: 15), ticks.add);

    clock.advance(const Duration(minutes: 20));
    await tester.pump(const Duration(seconds: 1));

    expect(ticks.last, Duration.zero);
  });

  testWidgets('cancel_StopsTicking', (tester) async {
    final clock = FakeClock();
    final ticks = <Duration>[];
    Countdown(clock)
      ..start(const Duration(seconds: 5), ticks.add)
      ..cancel();

    await elapse(tester, clock, const Duration(seconds: 5));

    expect(ticks, const [Duration(seconds: 5)]);
  });

  testWidgets('start_Again_ReplacesTheRunningCountdown', (tester) async {
    final clock = FakeClock();
    final first = <Duration>[];
    final second = <Duration>[];
    Countdown(clock)
      ..start(const Duration(seconds: 10), first.add)
      ..start(const Duration(seconds: 1), second.add);

    await elapse(tester, clock, const Duration(seconds: 10));

    expect(first, const [Duration(seconds: 10)]);
    expect(second, const [Duration(seconds: 1), Duration.zero]);
  });

  testWidgets('start_ZeroOrLess_EndsAtOnce', (tester) async {
    final ticks = <Duration>[];
    Countdown(FakeClock()).start(Duration.zero, ticks.add);
    await tester.pump(const Duration(seconds: 2));

    expect(ticks, const [Duration.zero]);
  });
}
