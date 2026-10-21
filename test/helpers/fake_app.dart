import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/seed/fake_seed.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/offline/app_database.dart';
import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/core/storage/preferences_store.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/storage/stored_session.dart';
import 'package:stockly/core/time/clock.dart';

import 'test_app.dart';
import 'test_doubles.dart';

export 'test_app.dart' show inMemoryDatabase, rawDio;

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

/// Provider overrides that run the whole app against the fake backend.
List<Override> fakeAppOverrides({
  required FakeBackendAdapter adapter,
  required TokenStorage tokens,
  Clock? clock,
  PreferencesStore? preferences,
  Locale deviceLocale = const Locale('ar'),
  AppDatabase? database,
}) => appOverrides(
  adapter: adapter,
  tokens: tokens,
  clock: clock,
  preferences: preferences,
  deviceLocale: deviceLocale,
  database: database,
);
