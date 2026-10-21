import 'dart:async';

import 'package:dio/dio.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/network/token_refresher.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/session/session_signals.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_doubles.dart';

const String productsPath = '/api/products';

/// Records log lines.
final class RecordingLogger implements AppLogger {
  final List<String> lines = [];

  @override
  void info(String message) => lines.add(message);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      lines.add(message);
}

/// A Dio stack with the real interceptors and refresher over a scripted
/// server. By default the server accepts only [validAccessToken] and the
/// refresh endpoint rotates to it after [refreshDelay].
final class NetworkHarness {
  new({LeaseService? leases}) {
    adapter = ScriptedAdapter(_serve);
    signals.stream.listen(emitted.add);
    const config = AppConfig(apiBaseUrl: 'https://api.stockly.test');
    refresher = TokenRefresher(
      refreshDio: buildRefreshDio(
        config: config,
        uuid: uuid,
        languageCode: () => language,
        logger: logger,
        logRequests: true,
        adapter: adapter,
      ),
      tokens: tokens,
      signals: signals,
      leases: leases ?? ImmediateLeaseService(),
    );
    dio = buildDio(
      config: config,
      uuid: uuid,
      languageCode: () => language,
      tokens: tokens,
      refresher: refresher,
      signals: signals,
      logger: logger,
      logRequests: true,
      adapter: adapter,
    );
  }

  late final ScriptedAdapter adapter;
  late final Dio dio;
  late final TokenRefresher refresher;
  final InMemoryTokenStorage tokens = InMemoryTokenStorage(storedSession());
  final SessionSignals signals = SessionSignals();
  final List<SessionSignal> emitted = [];
  final CountingUuidGenerator uuid = CountingUuidGenerator();
  final RecordingLogger logger = RecordingLogger();
  String language = 'ar';

  String validAccessToken = 'access-2';
  Duration refreshDelay = const Duration(milliseconds: 20);

  /// Overrides the answer of `POST /api/auth/refresh`.
  Future<ResponseBody> Function(RequestOptions options)? refreshAnswer;

  /// Overrides the answer of every other request.
  Future<ResponseBody> Function(RequestOptions options)? apiAnswer;

  List<RequestOptions> get refreshCalls =>
      adapter.requestsTo(ApiPaths.authRefresh);

  Future<ResponseBody> _serve(RequestOptions options) async {
    if (options.path == ApiPaths.authRefresh) {
      await Future<void>.delayed(refreshDelay);
      final answer = refreshAnswer;
      if (answer != null) {
        return await answer(options);
      }
      return jsonBody(
        200,
        authResponseJson(
          accessToken: validAccessToken,
          refreshToken: 'refresh-2',
        ),
      );
    }
    final answer = apiAnswer;
    if (answer != null) {
      return await answer(options);
    }
    final authorization = options.headers[HttpHeaderNames.authorization];
    if (authorization == '${HttpHeaderNames.bearerPrefix}$validAccessToken') {
      return jsonBody(200, {'ok': true});
    }
    return problemBody(401, 'Auth.Unauthenticated');
  }
}
