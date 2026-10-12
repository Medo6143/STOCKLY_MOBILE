import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/network/error_mapper.dart';
import 'package:stockly/core/network/request_extras.dart';

/// Debug-only request log (design §4.7). Logs method, path, status,
/// duration, correlation id, sizes and the ProblemDetails code and trace id.
/// Never logs headers, bodies, tokens, passwords or images, and hides the
/// values of the `search` and `barcode` query parameters.
final class RedactingLogInterceptor extends Interceptor {
  new(this._logger);

  final AppLogger _logger;

  static const String _stopwatchExtra = 'stockly.log.stopwatch';
  static const Set<String> _hiddenQueryKeys = {'search', 'barcode'};
  static const String _hidden = '***';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchExtra] = Stopwatch()..start();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.info(_line(response.requestOptions, response));
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    final problem = response == null ? null : mapErrorResponse(response);
    final details = switch (problem) {
      ApiFailure(:final code, :final info) =>
        ' code=${code.wire} traceId=${info.traceId}',
      UnknownApiFailure(:final rawCode, :final info) =>
        ' code=$rawCode traceId=${info.traceId}',
      _ => ' error=${err.type.name}',
    };
    _logger.info('${_line(err.requestOptions, response)}$details');
    handler.next(err);
  }

  String _line(RequestOptions options, Response<Object?>? response) {
    final stopwatch = options.extra[_stopwatchExtra];
    final elapsed = stopwatch is Stopwatch ? stopwatch.elapsedMilliseconds : 0;
    return '${options.method} ${_safePath(options.uri)} '
        '-> ${response?.statusCode} ${elapsed}ms '
        'cid=${options.extra[RequestExtras.correlationId]} '
        'out=${_sizeOf(options.data)}B in=${_sizeOf(response?.data)}B';
  }

  String _safePath(Uri uri) {
    if (uri.queryParameters.isEmpty) {
      return uri.path;
    }
    final query = uri.queryParameters.map(
      (key, value) =>
          MapEntry(key, _hiddenQueryKeys.contains(key) ? _hidden : value),
    );
    return Uri(path: uri.path, queryParameters: query).toString();
  }

  int _sizeOf(Object? data) => switch (data) {
    null => 0,
    FormData() => data.length,
    String() => utf8.encode(data).length,
    _ => utf8.encode(jsonEncode(data)).length,
  };
}
