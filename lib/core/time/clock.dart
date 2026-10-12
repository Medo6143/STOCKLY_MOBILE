import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The only source of the current time, so tests control time.
abstract interface class Clock {
  /// The current time in UTC.
  DateTime now();
}

final class SystemClock implements Clock {
  const new();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final clockProvider = Provider<Clock>((ref) => const SystemClock());
