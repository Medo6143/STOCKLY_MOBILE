import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/http_adapter_override.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/storage/preferences_store.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/time/clock.dart';

import 'invoices_doubles.dart';
import 'test_doubles.dart';

/// The configuration of a test app: the requests never leave the test,
/// an adapter answers them.
const AppConfig testConfig = AppConfig(apiBaseUrl: 'https://api.stockly.test');

/// A Dio over [adapter] without interceptors, for test set-up calls.
Dio rawDio(HttpClientAdapter adapter) =>
    buildBaseDio(config: testConfig, adapter: adapter);

/// Provider overrides that run the whole app against [adapter] (a
/// `TestServer` or a `ScriptedAdapter`) without platform channels or a
/// database file.
List<Override> appOverrides({
  required HttpClientAdapter adapter,
  required TokenStorage tokens,
  Clock? clock,
  PreferencesStore? preferences,
  Locale deviceLocale = const Locale('ar'),
  AppDatabase? database,
}) => [
  appConfigProvider.overrideWithValue(testConfig),
  httpAdapterOverrideProvider.overrideWithValue(adapter),
  tokenStorageProvider.overrideWithValue(tokens),
  leaseServiceProvider.overrideWithValue(ImmediateLeaseService()),
  preferencesStoreProvider.overrideWithValue(
    preferences ?? InMemoryPreferencesStore(),
  ),
  deviceLocaleProvider.overrideWithValue(deviceLocale),
  appLoggerProvider.overrideWithValue(const NoopLogger()),
  if (clock != null) clockProvider.overrideWithValue(clock),
  appDatabaseProvider.overrideWith((ref) {
    final db = database ?? inMemoryDatabase();
    ref.onDispose(db.close);
    return db;
  }),
  ...quietScanQueueOverrides(),
];

/// A fresh database in memory whose streams close at once, so widget tests
/// leave no pending timers.
AppDatabase inMemoryDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
