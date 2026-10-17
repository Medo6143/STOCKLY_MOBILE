import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/offline/backoff_policy.dart';

/// A [Random] that always returns [value] from [nextDouble].
final class _FixedRandom implements Random {
  new(this.value);

  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

void main() {
  test('NoJitter_DoublesFromBaseAndCapsAtMax', () {
    final policy = BackoffPolicy(_FixedRandom(0.5));

    expect(policy.delayFor(1), SyncTimings.backoffBase);
    expect(policy.delayFor(2), SyncTimings.backoffBase * 2);
    expect(policy.delayFor(3), SyncTimings.backoffBase * 4);
    expect(policy.delayFor(6), SyncTimings.backoffBase * 32);
    expect(policy.delayFor(7), SyncTimings.backoffMax);
    expect(policy.delayFor(100), SyncTimings.backoffMax);
  });

  test('Jitter_StaysWithin20Percent', () {
    final low = BackoffPolicy(_FixedRandom(0));
    final high = BackoffPolicy(_FixedRandom(1));

    expect(low.delayFor(1), const Duration(seconds: 24));
    expect(high.delayFor(1), const Duration(seconds: 36));
  });

  test('SeededRandom_IsRepeatable', () {
    final a = BackoffPolicy(Random(7));
    final b = BackoffPolicy(Random(7));

    for (var attempt = 1; attempt < 10; attempt++) {
      expect(a.delayFor(attempt), b.delayFor(attempt));
    }
  });

  test('AttemptZero_TreatedAsFirst', () {
    expect(
      BackoffPolicy(_FixedRandom(0.5)).delayFor(0),
      SyncTimings.backoffBase,
    );
  });
}
