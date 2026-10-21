import 'dart:math';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/token_refresher.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/background_sync.dart';
import 'package:stockly/core/offline/backoff_policy.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/core/storage/preferences_store.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/datasources/pending_scans_local_data_source.dart';
import 'package:stockly/features/invoices/data/sync/scan_sync_service.dart';
import 'package:workmanager/workmanager.dart' show Workmanager;

/// The background upload task (design §6.5): `workmanager` starts this in
/// its own isolate. It builds the object graph without widgets, runs the
/// queue once and closes the database. It always reports success: the
/// row states decide what happens next.
@pragma('vm:entry-point')
void scanSyncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final composition = await BackgroundSyncComposition.create();
    try {
      await composition.service.runOnce(force: false);
    } finally {
      await composition.close();
    }
    return true;
  });
}

/// The graph of the background isolate: database, secure token storage,
/// refresher, Dio with the app's interceptors (the language comes from the
/// stored preference), and the sync service.
final class BackgroundSyncComposition {
  new _(this.service, this._database);

  final ScanSyncService service;
  final AppDatabase _database;

  static Future<BackgroundSyncComposition> create() async {
    WidgetsFlutterBinding.ensureInitialized();
    final config = AppConfig.fromEnvironment();
    const uuid = PackageUuidGenerator();
    const clock = SystemClock();
    const logger = NoopLogger();
    final directories = await resolveAppDirectories();
    final database = openAppDatabase(directories);
    final language = _language(
      await DriftPreferencesStore(database.preferencesDao)
          .read(PreferenceKey.locale),
    );
    final tokens = SecureTokenStorage(const FlutterSecureStorage(), uuid);
    final leases = DriftLeaseService(
      database.leasesDao,
      clock,
      holder: uuid.v4(),
    );
    final signals = SessionSignals();
    final refresher = TokenRefresher(
      refreshDio: buildRefreshDio(
        config: config,
        uuid: uuid,
        languageCode: () => language,
        logger: logger,
        logRequests: false,
      ),
      tokens: tokens,
      signals: signals,
      leases: leases,
    );
    final dio = buildDio(
      config: config,
      uuid: uuid,
      languageCode: () => language,
      tokens: tokens,
      refresher: refresher,
      signals: signals,
      logger: logger,
      logRequests: false,
    );
    return BackgroundSyncComposition._(
      ScanSyncService(
        local: PendingScansLocalDataSource(
          database.pendingScansDao,
          directories,
        ),
        remote: InvoicesRemoteDataSource(dio),
        leases: leases,
        tokens: tokens,
        background: WorkmanagerSyncRegistrar(Workmanager()),
        backoff: BackoffPolicy(Random()),
        clock: clock,
      ),
      database,
    );
  }

  Future<void> close() => _database.close();

  /// `Accept-Language` from the stored choice, like `LocaleNotifier`
  /// (design §8.2): the device language when it is English, else Arabic.
  static String _language(String? stored) {
    final english = AppLocales.english.languageCode;
    final arabic = AppLocales.arabic.languageCode;
    return switch (LocalePreference.values.asNameMap()[stored]) {
      LocalePreference.en => english,
      LocalePreference.ar => arabic,
      LocalePreference.system || null =>
        PlatformDispatcher.instance.locale.languageCode == english
            ? english
            : arabic,
    };
  }
}
