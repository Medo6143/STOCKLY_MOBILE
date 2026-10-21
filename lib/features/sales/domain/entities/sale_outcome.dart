import 'package:stockly/core/error/failure.dart';

/// Whether a failed S1 may still have recorded the sale (design §6.8): the
/// request may have reached the server and only the answer was lost, or
/// the server failed after saving. Such a sale is kept and retried with
/// the same `clientRequestId`. Any other failure means this attempt was not
/// recorded; whether an earlier unknown attempt was is
/// [provesSaleNotRecorded].
extension SaleOutcomeX on Failure {
  bool get leavesSaleOutcomeUnknown => switch (this) {
    NetworkFailure() ||
    TimeoutFailure() ||
    ServerFailure() ||
    UnknownApiFailure() ||
    MalformedResponseFailure() => true,
    _ => false,
  };

  /// Whether this answer proves that no attempt with the same body and
  /// `clientRequestId` was recorded. The server rejects a malformed body,
  /// then looks the id up (a recorded sale answers `200`), then checks the
  /// products, so a rejection of the body or of its lines is proof.
  /// Session, permission and rate-limit answers come before the look-up and
  /// prove nothing: after an unknown outcome they keep the sale locked to
  /// its id.
  bool get provesSaleNotRecorded => switch (this) {
    ValidationFailure() ||
    InvalidInputFailure() ||
    NotFoundFailure() ||
    PayloadTooLargeFailure() => true,
    _ => false,
  };
}
