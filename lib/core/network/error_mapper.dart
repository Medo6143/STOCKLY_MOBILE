import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:stockly/core/config/limits.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/network/problem_details_dto.dart';
import 'package:stockly/core/network/request_extras.dart';

/// Maps a Dio error to a [Failure] (design §4.5). A [DioException] whose
/// `error` is already a [Failure] (set by the refresh interceptor) is passed
/// through unchanged.
Failure mapDioException(DioException exception) {
  if (exception.error case final Failure failure) {
    return failure;
  }
  final response = exception.response;
  return switch (exception.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => const TimeoutFailure(),
    DioExceptionType.badResponse when response != null => mapErrorResponse(
      response,
    ),
    // A cancelled call's result is ignored by its caller; the remaining
    // types (connection error, bad certificate, socket errors reported as
    // unknown) all mean the server could not be reached.
    DioExceptionType.badResponse ||
    DioExceptionType.cancel ||
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown => const NetworkFailure(),
  };
}

/// Maps an error response by its ProblemDetails `code`, never by `title` or
/// `detail`.
Failure mapErrorResponse(Response<Object?> response) {
  final status = response.statusCode ?? 0;
  final headerCorrelationId = response.headers.value(
    HttpHeaderNames.correlationId,
  );
  final problem = _parseProblem(response.data);
  if (problem == null) {
    return UnknownApiFailure(
      info: ApiProblemInfo(status: status, correlationId: headerCorrelationId),
    );
  }
  final info = ApiProblemInfo(
    status: status,
    traceId: problem.traceId,
    correlationId: problem.correlationId ?? headerCorrelationId,
  );
  final code = ApiErrorCode.fromWire(problem.code);
  if (code == null) {
    return UnknownApiFailure(info: info, rawCode: problem.code);
  }
  return failureForCode(
    code,
    info,
    fieldErrors: problem.errors ?? const {},
    retryAfter: parseRetryAfter(
      response.headers.value(HttpHeaderNames.retryAfter),
    ),
  );
}

/// The one [Failure] subtype for each [ApiErrorCode] (design §4.5 table).
ApiFailure failureForCode(
  ApiErrorCode code,
  ApiProblemInfo info, {
  Map<String, List<String>> fieldErrors = const {},
  Duration? retryAfter,
}) => switch (code) {
  ApiErrorCode.validationFailed => ValidationFailure(
    code,
    info,
    fieldErrors: fieldErrors,
  ),
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
  ApiErrorCode.saleUnitNotOfProduct ||
  ApiErrorCode.planInactive ||
  ApiErrorCode.billingFreePlan ||
  ApiErrorCode.billingMethodUnavailable => InvalidInputFailure(code, info),
  ApiErrorCode.authInvalidCredentials => InvalidCredentialsFailure(code, info),
  ApiErrorCode.authUnauthenticated ||
  ApiErrorCode.authInvalidRefreshToken ||
  ApiErrorCode.authRefreshTokenReused => SessionEndedFailure(code, info),
  ApiErrorCode.shopSuspended => ShopSuspendedFailure(code, info),
  ApiErrorCode.authForbidden ||
  ApiErrorCode.authNoActiveShop ||
  ApiErrorCode.productOpeningStockOwnerOnly => ForbiddenFailure(code, info),
  ApiErrorCode.productNotFound ||
  ApiErrorCode.productUnitNotFound ||
  ApiErrorCode.invoiceNotFound ||
  ApiErrorCode.saleNotFound ||
  ApiErrorCode.planNotFound ||
  ApiErrorCode.paymentNotFound ||
  ApiErrorCode.httpNotFound => NotFoundFailure(code, info),
  ApiErrorCode.authEmailTaken ||
  ApiErrorCode.productArchived ||
  ApiErrorCode.productDuplicateBarcode ||
  ApiErrorCode.productUnitDuplicateName ||
  ApiErrorCode.productUnitDuplicateBarcode ||
  ApiErrorCode.productUnitInUse ||
  ApiErrorCode.invoiceNotEditable ||
  ApiErrorCode.invoiceNotConfirmable ||
  ApiErrorCode.billingPaymentPending ||
  ApiErrorCode.billingNotCancelable => ConflictFailure(code, info),
  ApiErrorCode.authLockedOut => AccountLockedFailure(
    code,
    info,
    retryAfter: retryAfter ?? AuthLimits.defaultLockout,
  ),
  ApiErrorCode.authTooManyRequests => AuthRateLimitedFailure(
    code,
    info,
    retryAfter: retryAfter ?? AuthLimits.defaultRetryAfter,
  ),
  ApiErrorCode.invoiceImageTooLarge => PayloadTooLargeFailure(code, info),
  ApiErrorCode.scanRateLimited => ScanRateLimitedFailure(
    code,
    info,
    retryAfter: retryAfter ?? ScanLimits.defaultRetryAfter,
  ),
  ApiErrorCode.scanDailyQuotaExceeded => ScanQuotaExceededFailure(
    code,
    info,
    retryAfter: retryAfter,
  ),
  ApiErrorCode.serverUnexpected ||
  ApiErrorCode.httpMethodNotAllowed ||
  ApiErrorCode.httpUnsupportedMediaType ||
  ApiErrorCode.billingProviderUnavailable => ServerFailure(code, info),
};

/// Parses a `Retry-After` header in seconds. `null` when missing or not a
/// non-negative integer.
Duration? parseRetryAfter(String? header) {
  final seconds = header == null ? null : int.tryParse(header.trim());
  return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
}

ProblemDetailsDto? _parseProblem(Object? data) {
  final json = data is String ? _tryDecode(data) : data;
  if (json is! Map<String, Object?>) {
    return null;
  }
  try {
    return ProblemDetailsDto.fromJson(json);
  } on CheckedFromJsonException {
    return null;
  }
}

Object? _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
