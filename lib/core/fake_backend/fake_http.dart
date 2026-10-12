import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:stockly/core/error/api_error_code.dart';

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
  });

  final String method;
  final String path;
  final Map<String, Object?> headers;

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
}

/// A response of the fake backend.
@immutable
final class FakeResponse {
  const new(this.status, {this.json, this.problem = false});

  /// `200`/`201` with a JSON body.
  const new json(this.status, Map<String, Object?> this.json) : problem = false;

  /// `204 No Content`.
  const new noContent()
    : status = HttpStatus.noContent,
      json = null,
      problem = false;

  final int status;
  final Map<String, Object?>? json;

  /// `true` for `application/problem+json`.
  final bool problem;
}

/// One endpoint of the fake backend.
@immutable
final class FakeRoute {
  const new(this.method, this.path, this.handle);

  final String method;
  final String path;
  final FakeResponse Function(FakeRequest request) handle;
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
    HttpStatus.internalServerError: 'Internal Server Error',
  };

  FakeResponse problem(
    FakeRequest request,
    int status,
    ApiErrorCode code, {
    Map<String, List<String>>? errors,
  }) => FakeResponse(
    status,
    problem: true,
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

  static String invalidValue(String language) =>
      language == arabic ? 'القيمة غير مسموحة.' : 'This value is not allowed.';
}
