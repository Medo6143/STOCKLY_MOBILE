import 'package:dio/dio.dart';
import 'package:stockly/core/network/request_extras.dart';

/// Sets `Accept-Language` from the current app locale. The language is read
/// on every request, so a language change does not rebuild Dio.
final class AcceptLanguageInterceptor extends Interceptor {
  new(this._languageCode);

  final String Function() _languageCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[HttpHeaderNames.acceptLanguage] = _languageCode();
    handler.next(options);
  }
}
