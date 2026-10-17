import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:workmanager/workmanager.dart';

/// Names of the background upload tasks (design §6.5).
abstract final class SyncTaskNames {
  /// One-off task after a capture or a failed attempt.
  static const String scanUpload = 'stockly.scanUpload';

  /// Periodic task that retries waiting rows when the app is closed.
  static const String scanUploadPeriodic = 'stockly.scanUploadPeriodic';
}

/// Schedules the background upload (design §14, `workmanager`). Android
/// first; on iOS background work is best-effort (checkpoint 2, decision 14).
abstract interface class BackgroundSyncRegistrar {
  /// A one-off upload as soon as the device has a network. An upload that
  /// is already scheduled is kept.
  Future<void> requestUpload();

  /// The periodic retry, every [SyncTimings.periodic] with a network.
  Future<void> registerPeriodic();
}

final class WorkmanagerSyncRegistrar implements BackgroundSyncRegistrar {
  const new(this._workmanager);

  final Workmanager _workmanager;

  static final Constraints _network = Constraints(
    networkType: NetworkType.connected,
  );

  @override
  Future<void> requestUpload() => _workmanager.registerOneOffTask(
    SyncTaskNames.scanUpload,
    SyncTaskNames.scanUpload,
    constraints: _network,
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );

  @override
  Future<void> registerPeriodic() => _workmanager.registerPeriodicTask(
    SyncTaskNames.scanUploadPeriodic,
    SyncTaskNames.scanUploadPeriodic,
    frequency: SyncTimings.periodic,
    constraints: _network,
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

final backgroundSyncRegistrarProvider = Provider<BackgroundSyncRegistrar>(
  (ref) => WorkmanagerSyncRegistrar(Workmanager()),
);
