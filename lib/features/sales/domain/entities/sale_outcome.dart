import 'package:stockly/core/error/failure.dart';

/// Whether a failed S1 may still have recorded the sale (design §6.8): the
/// request may have reached the server and only the answer was lost, or
/// the server failed after saving. Such a sale is kept and retried with
/// the same `clientRequestId`; any other failure means it was not
/// recorded.
extension SaleOutcomeX on Failure {
  bool get leavesSaleOutcomeUnknown => switch (this) {
    NetworkFailure() ||
    TimeoutFailure() ||
    ServerFailure() ||
    UnknownApiFailure() ||
    MalformedResponseFailure() => true,
    _ => false,
  };
}
