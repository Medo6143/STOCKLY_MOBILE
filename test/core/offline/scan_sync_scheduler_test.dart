import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/offline/background_sync.dart';
import 'package:stockly/core/offline/scan_sync_scheduler.dart';

import '../../helpers/invoices_doubles.dart';
import '../../helpers/test_doubles.dart';

final class _FailingRegistrar implements BackgroundSyncRegistrar {
  @override
  Future<void> registerPeriodic() async =>
      throw PlatformException(code: 'unavailable');

  @override
  Future<void> requestUpload() async {}
}

/// The scheduler with fakes, built inside each test body so its streams
/// and timers live in the test's fake async zone.
final class _Harness {
  new({BackgroundSyncRegistrar? background}) {
    scheduler = ScanSyncScheduler(
      connectivity: connectivity,
      background: background ?? registrar,
      clock: clock,
      sync: ({required force}) async {
        runs.add(force);
        await gate?.future;
        return next;
      },
    );
  }

  final FakeClock clock = FakeClock();
  final FakeConnectivityMonitor connectivity = FakeConnectivityMonitor();
  final CountingSyncRegistrar registrar = CountingSyncRegistrar();
  final List<bool> runs = [];
  DateTime? next;
  Completer<void>? gate;
  late final ScanSyncScheduler scheduler;
}

void main() {
  testWidgets('Start_RegistersPeriodicAndRunsOnce', (tester) async {
    final h = _Harness();

    await h.scheduler.start();
    await h.scheduler.start();

    expect(h.registrar.periodic, 1);
    expect(h.runs, [false]);
    h.scheduler.dispose();
  });

  testWidgets('NoBackgroundService_StillRuns', (tester) async {
    final h = _Harness(background: _FailingRegistrar());

    await h.scheduler.start();

    expect(h.runs, [false]);
    h.scheduler.dispose();
  });

  testWidgets('NetworkBack_ForcedRun', (tester) async {
    final h = _Harness();
    await h.scheduler.start();
    await tester.pump();

    h.connectivity.set(online: false);
    await tester.pump();
    h.connectivity.set(online: true);
    await tester.pump();

    expect(h.runs, [false, true]);
    h.scheduler.dispose();
  });

  testWidgets('Resumed_Runs', (tester) async {
    final h = _Harness();
    await h.scheduler.start();

    await h.scheduler.onResumed();

    expect(h.runs, [false, false]);
    h.scheduler.dispose();
  });

  testWidgets('EarliestNextAttempt_TimerRunsAgain', (tester) async {
    final h = _Harness();
    h.next = h.clock.now().add(const Duration(seconds: 30));
    await h.scheduler.start();
    h.next = null;

    await tester.pump(const Duration(seconds: 29));
    expect(h.runs, [false]);
    await tester.pump(const Duration(seconds: 1));

    expect(h.runs, [false, false]);
    h.scheduler.dispose();
  });

  testWidgets('RequestDuringRun_OneMoreRunAfterIt', (tester) async {
    final h = _Harness();
    final gate = h.gate = Completer<void>();
    final first = h.scheduler.syncNow();
    await tester.pump();

    final second = h.scheduler.syncNow(force: true);
    final third = h.scheduler.syncNow();
    h.gate = null;
    gate.complete();
    await first;
    await second;
    await third;

    expect(h.runs, [false, true]);
    h.scheduler.dispose();
  });

  testWidgets('Disposed_NoMoreRuns', (tester) async {
    final h = _Harness();
    h.next = h.clock.now().add(const Duration(seconds: 5));
    await h.scheduler.start();
    h.scheduler.dispose();

    await tester.pump(const Duration(seconds: 10));
    await h.scheduler.syncNow();

    expect(h.runs, [false]);
  });
}
