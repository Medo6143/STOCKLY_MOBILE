import 'package:dio/dio.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/network/request_extras.dart';

/// Sets `X-Correlation-Id`: a new lower-case UUID per logical request, the
/// same id on the retry after a refresh (design §4.2).
final class CorrelationIdInterceptor extends Interceptor {
  new(this._uuid);

  final UuidGenerator _uuid;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final existing = options.extra[RequestExtras.correlationId];
    final id = existing is String ? existing : _uuid.v4();
    options.extra[RequestExtras.correlationId] = id;
    options.headers[HttpHeaderNames.correlationId] = id;
    handler.next(options);
  }
}
