import 'package:flutter/foundation.dart';
import 'package:stockly/core/error/api_error_code.dart';

/// Support details of one API error response: the HTTP status and the ids
/// the user can copy as an "error reference".
@immutable
final class ApiProblemInfo {
  const new({required this.status, this.traceId, this.correlationId});

  final int status;
  final String? traceId;
  final String? correlationId;

  /// The id shown as "error reference": the trace id, else the correlation id.
  String? get reference => traceId ?? correlationId;

  @override
  bool operator ==(Object other) =>
      other is ApiProblemInfo &&
      other.status == status &&
      other.traceId == traceId &&
      other.correlationId == correlationId;

  @override
  int get hashCode => Object.hash(status, traceId, correlationId);
}

/// Why a local (device-side) operation failed.
enum LocalFailureReason { cameraDenied, imageTooLarge, queueFull, storage }

/// Every expected failure, grouped by how the UI reacts (design §4.5).
@immutable
sealed class Failure {
  const new();
}

/// A ProblemDetails response with a code the app knows.
sealed class ApiFailure extends Failure {
  const new(this.code, this.info);

  final ApiErrorCode code;
  final ApiProblemInfo info;
}

/// `400 Validation.Failed`: field messages already localized by the server.
final class ValidationFailure extends ApiFailure {
  const new(super.code, super.info, {required this.fieldErrors});

  final Map<String, List<String>> fieldErrors;
}

/// `400` domain codes (precision, required names, image checks, ...).
final class InvalidInputFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// `401 Auth.InvalidCredentials`.
final class InvalidCredentialsFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// The session cannot be used any more: refresh rejected or `401` after the
/// one retry.
final class SessionEndedFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// `403 Shop.Suspended`.
final class ShopSuspendedFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// `403` role or membership codes.
final class ForbiddenFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// `404` (also a resource of another shop, contract §1.8).
final class NotFoundFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// `409`.
final class ConflictFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// `413 Invoice.ImageTooLarge`.
final class PayloadTooLargeFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// `429 Scan.RateLimited` with the server's `Retry-After`.
final class ScanRateLimitedFailure extends ApiFailure {
  const new(super.code, super.info, {required this.retryAfter});

  final Duration retryAfter;
}

/// `429 Scan.DailyQuotaExceeded`; [retryAfter] is the time until Cairo
/// midnight when the server sends it (contract v1.3).
final class ScanQuotaExceededFailure extends ApiFailure {
  const new(super.code, super.info, {this.retryAfter});

  final Duration? retryAfter;
}

/// `500 Server.Unexpected`, `405`, `415`.
final class ServerFailure extends ApiFailure {
  const new(super.code, super.info);
}

/// An error response whose code is unknown or that is not ProblemDetails
/// (proxy HTML, empty 502).
final class UnknownApiFailure extends Failure {
  const new({required this.info, this.rawCode});

  final String? rawCode;
  final ApiProblemInfo info;
}

/// No connection, DNS or socket error.
final class NetworkFailure extends Failure {
  const new();
}

/// Connect, send or receive timeout.
final class TimeoutFailure extends Failure {
  const new();
}

/// A 2xx body that does not match the contract.
final class MalformedResponseFailure extends Failure {
  const new();
}

/// A device-side failure (camera, storage, image size, queue size).
final class LocalFailure extends Failure {
  const new(this.reason);

  final LocalFailureReason reason;
}
