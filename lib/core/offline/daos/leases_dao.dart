import 'package:drift/drift.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/tables/leases.dart';

part 'leases_dao.g.dart';

@DriftAccessor(tables: [Leases])
class LeasesDao extends DatabaseAccessor<AppDatabase> with _$LeasesDaoMixin {
  new(super.attachedDatabase);

  /// Takes the lease [name] for [holder] until [expiresAt] when it is free,
  /// expired at [now], or already held by [holder]. Atomic.
  Future<bool> tryAcquire({
    required String name,
    required String holder,
    required DateTime now,
    required DateTime expiresAt,
  }) => transaction(() async {
    final current = await (select(
      leases,
    )..where((l) => l.name.equals(name))).getSingleOrNull();
    final free =
        current == null ||
        current.holder == holder ||
        !current.expiresAt.isAfter(now);
    if (!free) {
      return false;
    }
    await into(leases).insertOnConflictUpdate(
      LeasesCompanion.insert(name: name, holder: holder, expiresAt: expiresAt),
    );
    return true;
  });

  /// Gives the lease back if [holder] still holds it.
  Future<void> release({required String name, required String holder}) =>
      (delete(
        leases,
      )..where((l) => l.name.equals(name) & l.holder.equals(holder))).go();
}
