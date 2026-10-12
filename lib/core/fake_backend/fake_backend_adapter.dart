import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_config.dart';
import 'package:stockly/core/fake_backend/fake_backend_controls.dart';
import 'package:stockly/core/fake_backend/fake_backend_state.dart';
import 'package:stockly/core/fake_backend/fake_http.dart';
import 'package:stockly/core/fake_backend/handlers/fake_auth_handler.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/time/clock.dart';

/// The fake backend at the HTTP boundary (design §12): every class above Dio
/// runs unchanged, and errors are contract-shaped ProblemDetails, so the
/// app gets the same `Failure`s as from the real API.
final class FakeBackendAdapter implements HttpClientAdapter {
  new({
    required this.state,
    required FakeBackendConfig config,
    required Clock clock,
    required UuidGenerator uuid,
  }) : _config = config,
       _clock = clock,
       _uuid = uuid,
       controls = FakeBackendControls(config) {
    _problems = FakeProblems(_traceId);
    final handlers = <FakeHandler>[
      FakeAuthHandler(
        state: state,
        config: config,
        controls: controls,
        clock: clock,
        uuid: uuid,
        problems: _problems,
      ),
    ];
    _routes = [for (final handler in handlers) ...handler.routes];
  }

  final FakeBackendState state;

  /// Runtime switches for the debug panel.
  final FakeBackendControls controls;
  final FakeBackendConfig _config;
  final Clock _clock;
  final UuidGenerator _uuid;
  late final FakeProblems _problems;
  late final List<FakeRoute> _routes;

  static const String _defaultLanguage = 'ar';
  static const String _english = 'en';
  static const String _jsonContentType = 'application/json; charset=utf-8';
  static const String _problemContentType =
      'application/problem+json; charset=utf-8';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (_config.latency > Duration.zero) {
      await Future<void>.delayed(_config.latency);
    }
    if (controls.offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Fake backend is offline.',
      );
    }
    final headers = {
      for (final entry in options.headers.entries)
        entry.key.toLowerCase(): entry.value,
    };
    final correlationId = switch (headers[HttpHeaderNames.correlationId
        .toLowerCase()]) {
      final String id => id,
      _ => _uuid.v4(),
    };
    final bytes = await _readAll(requestStream);
    final request = FakeRequest(
      method: options.method.toUpperCase(),
      path: options.uri.path,
      headers: headers,
      body: null,
      language:
          headers[HttpHeaderNames.acceptLanguage.toLowerCase()] == _english
          ? _english
          : _defaultLanguage,
      correlationId: correlationId,
    );
    final forced = controls.failNextWith;
    controls.failNextWith = null;
    final response = forced == null
        ? _dispatch(request, bytes, headers)
        : _problems.forced(request, forced, retryAfter: _config.authWindow);
    return _toResponseBody(response, correlationId);
  }

  /// Ends every access token now (debug panel): the next authenticated call
  /// gets `401` and the app refreshes.
  void expireAccessTokens() => state.expireAccessTokens(_clock.now());

  /// Suspends or reactivates [shopId] (debug panel).
  void setShopSuspended(String shopId, {required bool suspended}) =>
      state.setShopStatus(shopId, suspended: suspended);

  FakeResponse _dispatch(
    FakeRequest bare,
    List<int> bytes,
    Map<String, Object?> headers,
  ) {
    final candidates = _routes.where((r) => r.path == bare.path).toList();
    if (candidates.isEmpty) {
      return _problems.problem(
        bare,
        HttpStatus.notFound,
        ApiErrorCode.httpNotFound,
      );
    }
    final route = candidates.where((r) => r.method == bare.method).firstOrNull;
    if (route == null) {
      return _problems.problem(
        bare,
        HttpStatus.methodNotAllowed,
        ApiErrorCode.httpMethodNotAllowed,
      );
    }
    if (bytes.isEmpty) {
      return route.handle(bare);
    }
    final contentType = headers[HttpHeaders.contentTypeHeader.toLowerCase()];
    if (contentType is! String || !Transformer.isJsonMimeType(contentType)) {
      return _problems.problem(
        bare,
        HttpStatus.unsupportedMediaType,
        ApiErrorCode.httpUnsupportedMediaType,
      );
    }
    final Object? body;
    try {
      body = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return _problems.validation(bare, const {});
    }
    return route.handle(
      FakeRequest(
        method: bare.method,
        path: bare.path,
        headers: bare.headers,
        body: body,
        language: bare.language,
        correlationId: bare.correlationId,
      ),
    );
  }

  ResponseBody _toResponseBody(FakeResponse response, String correlationId) {
    final json = response.json;
    return ResponseBody.fromString(
      json == null ? '' : jsonEncode(json),
      response.status,
      headers: {
        HttpHeaders.contentTypeHeader: [
          if (response.problem) _problemContentType else _jsonContentType,
        ],
        HttpHeaderNames.correlationId.toLowerCase(): [correlationId],
        for (final MapEntry(:key, :value) in response.headers.entries)
          key.toLowerCase(): [value],
      },
    );
  }

  Future<List<int>> _readAll(Stream<Uint8List>? stream) async {
    if (stream == null) {
      return const [];
    }
    final builder = BytesBuilder(copy: false);
    await stream.forEach(builder.add);
    return builder.takeBytes();
  }

  /// A W3C trace id like the backend's (`00-<32 hex>-<16 hex>-00`).
  String _traceId() {
    final hex = _uuid.v4().replaceAll('-', '');
    return '00-$hex-${hex.substring(0, 16)}-00';
  }

  @override
  void close({bool force = false}) {}
}
