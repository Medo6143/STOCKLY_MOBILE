import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/network/request_extras.dart';

/// A request as the fake backend sees it.
@immutable
final class FakeRequest {
  const new({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
    required this.language,
    required this.correlationId,
    this.query = const {},
    this.params = const {},
  });

  final String method;
  final String path;
  final Map<String, Object?> headers;

  /// The query string parameters.
  final Map<String, String> query;

  /// The values of the route's `{name}` path segments.
  final Map<String, String> params;

  /// The decoded JSON body, or `null` when there is none.
  final Object? body;

  /// `ar` or `en` from `Accept-Language` (default `ar`, contract §1.5).
  final String language;
  final String correlationId;

  /// The `Bearer` token, or `null`.
  String? get bearerToken {
    final header = headers[HttpHeaders.authorizationHeader.toLowerCase()];
    const prefix = 'Bearer ';
    return header is String && header.startsWith(prefix)
        ? header.substring(prefix.length)
        : null;
  }

  /// The body as a JSON object, or `null`.
  Map<String, Object?>? get jsonObject {
    final value = body;
    return value is Map<String, Object?> ? value : null;
  }

  String get instance => '$method $path';

  /// This request with [body] and the route's [params].
  FakeRequest copyWith({
    required Object? body,
    required Map<String, String> params,
  }) => FakeRequest(
    method: method,
    path: path,
    headers: headers,
    body: body,
    language: language,
    correlationId: correlationId,
    query: query,
    params: params,
  );
}

/// A response of the fake backend.
@immutable
final class FakeResponse {
  const new(
    this.status, {
    this.json,
    this.problem = false,
    this.headers = const {},
  });

  /// `200`/`201` with a JSON body.
  const new json(this.status, Map<String, Object?> this.json)
    : problem = false,
      headers = const {};

  /// `204 No Content`.
  const new noContent()
    : status = HttpStatus.noContent,
      json = null,
      problem = false,
      headers = const {};

  final int status;
  final Map<String, Object?>? json;

  /// `true` for `application/problem+json`.
  final bool problem;

  /// Extra response headers (for example `Retry-After`).
  final Map<String, String> headers;
}

/// One endpoint of the fake backend. A `{name}` segment of [path] matches
/// a lower- or upper-case UUID, like the backend's `{id:guid}` routes.
@immutable
final class FakeRoute {
  const new(this.method, this.path, this.handle);

  final String method;
  final String path;
  final FakeResponse Function(FakeRequest request) handle;

  static final RegExp _uuid = RegExp(
    '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{12}$',
  );

  /// The number of `{name}` segments; literal routes win over templates.
  int get parameterCount =>
      path.split('/').where((s) => s.startsWith('{')).length;

  /// The path parameters when [requestPath] matches, else `null`.
  Map<String, String>? match(String requestPath) {
    final expected = path.split('/');
    final actual = requestPath.split('/');
    if (expected.length != actual.length) {
      return null;
    }
    final params = <String, String>{};
    for (var i = 0; i < expected.length; i++) {
      final segment = expected[i];
      if (segment.startsWith('{') && segment.endsWith('}')) {
        if (!_uuid.hasMatch(actual[i])) {
          return null;
        }
        params[segment.substring(1, segment.length - 1)] = actual[i]
            .toLowerCase();
      } else if (segment != actual[i]) {
        return null;
      }
    }
    return params;
  }
}

/// A handler for one API area (auth, products, ...).
abstract interface class FakeHandler {
  List<FakeRoute> get routes;
}

/// Builds RFC 7807 bodies exactly as the backend does (contract §1.8).
final class FakeProblems {
  new(this._newTraceId);

  final String Function() _newTraceId;

  static const Map<int, String> _types = {
    HttpStatus.badRequest: 'https://tools.ietf.org/html/rfc9110#section-15.5.1',
    HttpStatus.unauthorized:
        'https://tools.ietf.org/html/rfc9110#section-15.5.2',
    HttpStatus.forbidden: 'https://tools.ietf.org/html/rfc9110#section-15.5.4',
    HttpStatus.notFound: 'https://tools.ietf.org/html/rfc9110#section-15.5.5',
    HttpStatus.methodNotAllowed:
        'https://tools.ietf.org/html/rfc9110#section-15.5.6',
    HttpStatus.conflict: 'https://tools.ietf.org/html/rfc9110#section-15.5.10',
    HttpStatus.unsupportedMediaType:
        'https://tools.ietf.org/html/rfc9110#section-15.5.16',
    HttpStatus.locked: 'https://tools.ietf.org/html/rfc4918#section-11.3',
    HttpStatus.tooManyRequests: 'https://tools.ietf.org/html/rfc6585#section-4',
    HttpStatus.internalServerError:
        'https://tools.ietf.org/html/rfc9110#section-15.6.1',
  };

  static const Map<int, String> _titles = {
    HttpStatus.badRequest: 'Bad Request',
    HttpStatus.unauthorized: 'Unauthorized',
    HttpStatus.forbidden: 'Forbidden',
    HttpStatus.notFound: 'Not Found',
    HttpStatus.methodNotAllowed: 'Method Not Allowed',
    HttpStatus.conflict: 'Conflict',
    HttpStatus.unsupportedMediaType: 'Unsupported Media Type',
    HttpStatus.locked: 'Locked',
    HttpStatus.tooManyRequests: 'Too Many Requests',
    HttpStatus.internalServerError: 'Internal Server Error',
  };

  /// The status the backend answers [code] with (contract §9).
  static int statusOf(ApiErrorCode code) => switch (code) {
    ApiErrorCode.validationFailed ||
    ApiErrorCode.shopNameRequired ||
    ApiErrorCode.shopUnknownType ||
    ApiErrorCode.productNameRequired ||
    ApiErrorCode.productUnitNameRequired ||
    ApiErrorCode.productUnitBaseUnitCannotBeRemoved ||
    ApiErrorCode.productUnitBaseUnitFactorFixed ||
    ApiErrorCode.precisionTooManyDecimals ||
    ApiErrorCode.precisionNegative ||
    ApiErrorCode.precisionNotPositive ||
    ApiErrorCode.precisionOutOfRange ||
    ApiErrorCode.stockZeroChange ||
    ApiErrorCode.stockNoteRequired ||
    ApiErrorCode.invoiceImageRequired ||
    ApiErrorCode.invoiceUnsupportedImageType ||
    ApiErrorCode.invoiceLineProductRequired ||
    ApiErrorCode.invoiceUnitNotOfProduct ||
    ApiErrorCode.saleArchivedProduct ||
    ApiErrorCode.saleUnitNotOfProduct => HttpStatus.badRequest,
    ApiErrorCode.authUnauthenticated ||
    ApiErrorCode.authInvalidCredentials ||
    ApiErrorCode.authInvalidRefreshToken ||
    ApiErrorCode.authRefreshTokenReused => HttpStatus.unauthorized,
    ApiErrorCode.authForbidden ||
    ApiErrorCode.authNoActiveShop ||
    ApiErrorCode.shopSuspended ||
    ApiErrorCode.productOpeningStockOwnerOnly => HttpStatus.forbidden,
    ApiErrorCode.httpNotFound ||
    ApiErrorCode.productNotFound ||
    ApiErrorCode.productUnitNotFound ||
    ApiErrorCode.invoiceNotFound ||
    ApiErrorCode.saleNotFound => HttpStatus.notFound,
    ApiErrorCode.httpMethodNotAllowed => HttpStatus.methodNotAllowed,
    ApiErrorCode.authEmailTaken ||
    ApiErrorCode.productArchived ||
    ApiErrorCode.productDuplicateBarcode ||
    ApiErrorCode.productUnitDuplicateName ||
    ApiErrorCode.productUnitDuplicateBarcode ||
    ApiErrorCode.productUnitInUse ||
    ApiErrorCode.invoiceNotEditable ||
    ApiErrorCode.invoiceNotConfirmable => HttpStatus.conflict,
    ApiErrorCode.invoiceImageTooLarge => HttpStatus.requestEntityTooLarge,
    ApiErrorCode.httpUnsupportedMediaType => HttpStatus.unsupportedMediaType,
    ApiErrorCode.authLockedOut => HttpStatus.locked,
    ApiErrorCode.authTooManyRequests ||
    ApiErrorCode.scanRateLimited ||
    ApiErrorCode.scanDailyQuotaExceeded => HttpStatus.tooManyRequests,
    ApiErrorCode.serverUnexpected => HttpStatus.internalServerError,
  };

  /// [code] with its contract status, as when the debug panel forces the
  /// next request to fail. Throttling codes carry [retryAfter].
  FakeResponse forced(
    FakeRequest request,
    ApiErrorCode code, {
    required Duration retryAfter,
  }) {
    final status = statusOf(code);
    final throttled =
        status == HttpStatus.locked || status == HttpStatus.tooManyRequests;
    return problem(
      request,
      status,
      code,
      errors: code == ApiErrorCode.validationFailed ? const {} : null,
      retryAfter: throttled ? retryAfter : null,
    );
  }

  /// `Retry-After` in whole seconds, rounded up and at least 1, like the
  /// backend.
  static String retryAfterSeconds(Duration remaining) {
    final seconds =
        (remaining.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
        Duration.microsecondsPerSecond;
    return '${seconds < 1 ? 1 : seconds}';
  }

  FakeResponse problem(
    FakeRequest request,
    int status,
    ApiErrorCode code, {
    Map<String, List<String>>? errors,
    Duration? retryAfter,
  }) => FakeResponse(
    status,
    problem: true,
    headers: {
      if (retryAfter != null)
        HttpHeaderNames.retryAfter: retryAfterSeconds(retryAfter),
    },
    json: {
      'type': _types[status],
      'title': _titles[status],
      'status': status,
      'detail': FakeMessages.detail(code, request.language),
      'instance': request.instance,
      'code': code.wire,
      'traceId': _newTraceId(),
      'correlationId': request.correlationId,
      'errors': ?errors,
    },
  );

  FakeResponse validation(
    FakeRequest request,
    Map<String, List<String>> errors,
  ) => problem(
    request,
    HttpStatus.badRequest,
    ApiErrorCode.validationFailed,
    errors: errors,
  );
}

/// Server-side texts of the fake backend, localized by `Accept-Language`
/// like the real server's. The app never shows or switches on `detail`;
/// field messages under `errors` are displayed as they are.
abstract final class FakeMessages {
  static const String arabic = 'ar';

  static String detail(ApiErrorCode code, String language) {
    final ar = language == arabic;
    return switch (code) {
      ApiErrorCode.validationFailed =>
        ar ? 'بيانات الطلب غير صحيحة.' : 'The request is not valid.',
      ApiErrorCode.authEmailTaken =>
        ar
            ? 'البريد الإلكتروني مسجل بالفعل.'
            : 'This email is already registered.',
      ApiErrorCode.authInvalidCredentials =>
        ar ? 'البريد أو كلمة المرور غير صحيحة.' : 'Wrong email or password.',
      ApiErrorCode.authNoActiveShop =>
        ar ? 'لا يوجد متجر نشط لهذا المستخدم.' : 'The user has no active shop.',
      ApiErrorCode.authInvalidRefreshToken =>
        ar ? 'رمز التحديث غير صالح.' : 'The refresh token is not valid.',
      ApiErrorCode.authRefreshTokenReused =>
        ar ? 'تم استخدام رمز تحديث ملغي.' : 'A revoked refresh token was used.',
      ApiErrorCode.authUnauthenticated =>
        ar ? 'يجب تسجيل الدخول.' : 'Authentication is required.',
      ApiErrorCode.shopNameRequired =>
        ar ? 'اسم المتجر مطلوب.' : 'The shop name is required.',
      ApiErrorCode.shopUnknownType =>
        ar ? 'نوع المتجر غير مدعوم.' : 'This shop type is not supported.',
      ApiErrorCode.shopSuspended =>
        ar ? 'تم إيقاف المتجر.' : 'The shop is suspended.',
      ApiErrorCode.authLockedOut =>
        ar
            ? 'محاولات دخول فاشلة كثيرة. تم قفل حسابك لمدة 15 دقيقة.'
            : 'Too many failed sign-in attempts. Your account is locked '
                  'for 15 minutes.',
      ApiErrorCode.authTooManyRequests =>
        ar
            ? 'طلبات كثيرة جداً. يرجى الانتظار قليلاً.'
            : 'Too many requests. Please wait a moment and try again.',
      _ => ar ? 'حدث خطأ.' : 'An error occurred.',
    };
  }

  static String required(String language) =>
      language == arabic ? 'هذا الحقل مطلوب.' : 'This field is required.';

  static String invalidEmail(String language) => language == arabic
      ? 'البريد الإلكتروني غير صحيح.'
      : 'The email address is not valid.';

  static String tooLong(String language, int max) => language == arabic
      ? 'الحد الأقصى $max حرفًا.'
      : 'At most $max characters.';

  static String weakPassword(String language) => language == arabic
      ? 'كلمة المرور من 8 إلى 128 حرفًا وفيها حرف ورقم على الأقل.'
      : 'The password needs 8 to 128 characters with a letter and a digit.';

  static String decimalFormat(String language) => language == arabic
      ? 'القيمة لازم تكون رقم مكتوب كنص، زي "12.50".'
      : 'The value must be a decimal string such as "12.50".';

  static String invalidValue(String language) =>
      language == arabic ? 'القيمة غير مسموحة.' : 'This value is not allowed.';
}
