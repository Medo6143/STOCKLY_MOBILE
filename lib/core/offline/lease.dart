import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/daos/leases_dao.dart';
import 'package:stockly/core/time/clock.dart';

/// Names of the cross-isolate leases.
abstract final class LeaseNames {
  static const String authRefresh = 'auth_refresh';
}

/// Lease timings.
abstract final class LeaseTimings {
  /// A refresh holds its lease at most this long, so a killed isolate never
  /// blocks refreshes for good.
  static const Duration authRefreshTtl = Duration(seconds: 30);

  /// Delay between two attempts to take a busy lease.
  static const Duration pollInterval = Duration(milliseconds: 100);
}

/// Mutual exclusion between isolates (app and background sync) through the
/// Drift `leases` table.
abstract interface class LeaseService {
  /// Runs [action] while holding the lease [name]. Returns `null` without
  /// running [action] when the lease stays busy for [wait].
  Future<T?> withLease<T>(
    String name, {
    required Duration ttl,
    required Duration wait,
    required Future<T> Function() action,
  });
}

final class DriftLeaseService implements LeaseService {
  new(this._dao, this._clock, {required this.holder});

  final LeasesDao _dao;
  final Clock _clock;

  /// Random id of this isolate's service.
  final String holder;

  @override
  Future<T?> withLease<T>(
    String name, {
    required Duration ttl,
    required Duration wait,
    required Future<T> Function() action,
  }) async {
    final deadline = _clock.now().add(wait);
    while (!await _tryAcquire(name, ttl)) {
      if (!_clock.now().isBefore(deadline)) {
        return null;
      }
      await Future<void>.delayed(LeaseTimings.pollInterval);
    }
    try {
      return await action();
    } finally {
      await _dao.release(name: name, holder: holder);
    }
  }

  Future<bool> _tryAcquire(String name, Duration ttl) {
    final now = _clock.now();
    return _dao.tryAcquire(
      name: name,
      holder: holder,
      now: now,
      expiresAt: now.add(ttl),
    );
  }
}

final leaseServiceProvider = Provider<LeaseService>(
  (ref) => DriftLeaseService(
    ref.watch(appDatabaseProvider).leasesDao,
    ref.watch(clockProvider),
    holder: ref.watch(uuidGeneratorProvider).v4(),
  ),
);
