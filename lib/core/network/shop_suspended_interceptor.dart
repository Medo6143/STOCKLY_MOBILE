import 'package:dio/dio.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/network/error_mapper.dart';
import 'package:stockly/core/session/session_signals.dart';

/// On `403 Shop.Suspended` emits `SessionSignals.shopSuspended`, so the
/// router moves to the suspended screen.
final class ShopSuspendedInterceptor extends Interceptor {
  new(this._signals);

  final SessionSignals _signals;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final response = err.response;
    if (err.type == DioExceptionType.badResponse && response != null) {
      if (mapErrorResponse(response) case final ShopSuspendedFailure failure) {
        _signals.shopSuspended(failure);
      }
    }
    handler.next(err);
  }
}
