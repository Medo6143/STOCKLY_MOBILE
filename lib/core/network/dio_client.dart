import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/config/network_timeouts.dart';
import 'package:stockly/core/fake_backend/fake_backend_provider.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/network/accept_language_interceptor.dart';
import 'package:stockly/core/network/auth_header_interceptor.dart';
import 'package:stockly/core/network/correlation_id_interceptor.dart';
import 'package:stockly/core/network/redacting_log_interceptor.dart';
import 'package:stockly/core/network/refresh_interceptor.dart';
import 'package:stockly/core/network/shop_suspended_interceptor.dart';
import 'package:stockly/core/network/token_refresher.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/session/session_signals.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';

/// A Dio with the contract's base options. [adapter] is the fake backend in
/// fake mode; everything else is identical in both modes.
Dio buildBaseDio({required AppConfig config, HttpClientAdapter? adapter}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: NetworkTimeouts.connect,
      sendTimeout: NetworkTimeouts.send,
      receiveTimeout: NetworkTimeouts.receive,
      contentType: Headers.jsonContentType,
    ),
  );
  if (adapter != null) {
    dio.httpClientAdapter = adapter;
  }
  return dio;
}

/// The app's Dio with every interceptor in the order of design §4.1.
Dio buildDio({
  required AppConfig config,
  required UuidGenerator uuid,
  required String Function() languageCode,
  required TokenStorage tokens,
  required TokenRefresher refresher,
  required SessionSignals signals,
  required AppLogger logger,
  required bool logRequests,
  HttpClientAdapter? adapter,
}) {
  final dio = buildBaseDio(config: config, adapter: adapter);
  dio.interceptors.addAll([
    CorrelationIdInterceptor(uuid),
    AcceptLanguageInterceptor(languageCode),
    AuthHeaderInterceptor(tokens),
    RefreshInterceptor(
      dio: () => dio,
      refresher: refresher,
      tokens: tokens,
      signals: signals,
    ),
    ShopSuspendedInterceptor(signals),
    if (logRequests) RedactingLogInterceptor(logger),
  ]);
  return dio;
}

/// The Dio used only for `POST /api/auth/refresh`: no auth interceptors,
/// and timeouts that end before the refresh lease expires.
Dio buildRefreshDio({
  required AppConfig config,
  required UuidGenerator uuid,
  required String Function() languageCode,
  required AppLogger logger,
  required bool logRequests,
  HttpClientAdapter? adapter,
}) {
  final dio = buildBaseDio(config: config, adapter: adapter);
  dio.options
    ..sendTimeout = NetworkTimeouts.refreshSend
    ..receiveTimeout = NetworkTimeouts.refreshReceive;
  dio.interceptors.addAll([
    CorrelationIdInterceptor(uuid),
    AcceptLanguageInterceptor(languageCode),
    if (logRequests) RedactingLogInterceptor(logger),
  ]);
  return dio;
}

final refreshDioProvider = Provider<Dio>(
  (ref) => buildRefreshDio(
    config: ref.watch(appConfigProvider),
    uuid: ref.watch(uuidGeneratorProvider),
    languageCode: () => ref.read(localeProvider).languageCode,
    logger: ref.watch(appLoggerProvider),
    logRequests: kDebugMode,
    adapter: ref.watch(fakeBackendProvider),
  ),
);

final tokenRefresherProvider = Provider<TokenRefresher>(
  (ref) => TokenRefresher(
    refreshDio: ref.watch(refreshDioProvider),
    tokens: ref.watch(tokenStorageProvider),
    signals: ref.watch(sessionSignalsProvider),
    leases: ref.watch(leaseServiceProvider),
  ),
);

final dioProvider = Provider<Dio>(
  (ref) => buildDio(
    config: ref.watch(appConfigProvider),
    uuid: ref.watch(uuidGeneratorProvider),
    languageCode: () => ref.read(localeProvider).languageCode,
    tokens: ref.watch(tokenStorageProvider),
    refresher: ref.watch(tokenRefresherProvider),
    signals: ref.watch(sessionSignalsProvider),
    logger: ref.watch(appLoggerProvider),
    logRequests: kDebugMode,
    adapter: ref.watch(fakeBackendProvider),
  ),
);
