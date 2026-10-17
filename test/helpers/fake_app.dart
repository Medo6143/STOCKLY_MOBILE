import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_provider.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/core/storage/preferences_store.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/storage/stored_session.dart';
import 'package:stockly/core/time/clock.dart';

import 'invoices_doubles.dart';
import 'test_doubles.dart';

const AppConfig fakeConfig = AppConfig(
  backendMode: BackendMode.fake,
  apiBaseUrl: AppConfig.fakeApiBaseUrl,
);

/// A fake backend with the seed accounts and no latency.
FakeBackendAdapter fakeBackend({
  FakeClock? clock,
  FakeBackendState? state,
  FakeBackendConfig config = const FakeBackendConfig(latency: Duration.zero),
}) {
  final time = clock ?? FakeClock();
  return FakeBackendAdapter(
    state: state ?? FakeSeed.pharmacy(time.now()),
    config: config,
    clock: time,
    uuid: const PackageUuidGenerator(),
  );
}

/// A Dio over [adapter] without interceptors, for test set-up calls.
Dio rawDio(HttpClientAdapter adapter) =>
    buildBaseDio(config: fakeConfig, adapter: adapter);

/// Signs in on the fake backend and returns the session to store.
Future<StoredSession> loginOn(
  FakeBackendAdapter adapter, {
  String email = FakeSeed.ownerEmail,
}) async {
  final response = await rawDio(adapter).post<Object?>(
    ApiPaths.authLogin,
    data: {'email': email, 'password': FakeSeed.password},
    options: Options(extra: {RequestExtras.anonymous: true}),
  );
  return StoredSession.fromAuthResponse(
    AuthResponseDto.fromJson(requireJsonObject(response.data)),
  );
}

/// Provider overrides that run the whole app against [adapter] without
/// platform channels or a database file.
List<Override> fakeAppOverrides({
  required FakeBackendAdapter adapter,
  required TokenStorage tokens,
  Clock? clock,
  PreferencesStore? preferences,
  Locale deviceLocale = const Locale('ar'),
}) => [
  appConfigProvider.overrideWithValue(fakeConfig),
  fakeBackendProvider.overrideWithValue(adapter),
  tokenStorageProvider.overrideWithValue(tokens),
  leaseServiceProvider.overrideWithValue(ImmediateLeaseService()),
  preferencesStoreProvider.overrideWithValue(
    preferences ?? InMemoryPreferencesStore(),
  ),
  deviceLocaleProvider.overrideWithValue(deviceLocale),
  appLoggerProvider.overrideWithValue(const NoopLogger()),
  if (clock != null) clockProvider.overrideWithValue(clock),
  ...quietScanQueueOverrides(),
];
