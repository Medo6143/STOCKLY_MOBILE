import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/sales/domain/entities/cart_line.dart';
import 'package:stockly/features/sales/domain/entities/sale_request.dart';
import 'package:stockly/features/sales/domain/entities/sale_submission.dart';

part 'quick_sale_state.freezed.dart';

/// Where the quick sale is (design §6.8, §11 cart rules).
enum QuickSalePhase {
  /// The cart can be edited and submitted.
  editing,

  /// S1 is running.
  submitting,

  /// The last attempt's outcome is unknown: only Retry (same id, same
  /// body) or Discard.
  lockedUnknownOutcome,
}

/// The quick-sale cart (design §11): lines, note, the sale's
/// `clientRequestId` once submitted, the phase and the last failure.
@freezed
abstract class QuickSaleState with _$QuickSaleState {
  const factory({
    @Default(<CartLine>[]) List<CartLine> lines,
    @Default('') String note,

    /// Created on the first submit and kept until the outcome is known.
    String? clientRequestId,

    /// The exact request of a locked sale; Retry sends it again.
    SaleRequest? lockedRequest,

    /// When the locked sale was first stored (a sale reopened at start).
    DateTime? lockedSince,
    @Default(QuickSalePhase.editing) QuickSalePhase phase,

    /// The last submit failure, shown in the banner.
    Failure? failure,

    /// Lines with a server field error (`items[i].*`), by line key.
    @Default(<int, List<String>>{}) Map<int, List<String>> lineMessages,

    /// Lines that cannot be sent as typed, by line key.
    @Default(<int>{}) Set<int> lineErrors,

    /// Barcode or product lookups still running (a wedge scanner can send
    /// the next barcode before the first answer).
    @Default(0) int lookupsRunning,

    /// The last lookup failed (`Product.NotFound`: no such barcode).
    Failure? lookupFailure,

    /// The cart already has the most lines a sale may have.
    @Default(false) bool lineLimitReached,

    /// The last recorded sale; [submissionCount] grows with each one.
    SaleSubmission? lastSubmission,
    @Default(0) int submissionCount,
    @Default(1) int nextLineKey,
  }) = _QuickSaleState;
}

extension QuickSaleStateX on QuickSaleState {
  bool get isLocked => phase == QuickSalePhase.lockedUnknownOutcome;

  bool get isEditable => phase == QuickSalePhase.editing;

  bool get isLookingUp => lookupsRunning > 0;

  bool get canSubmit =>
      isEditable && lines.isNotEmpty && lines.every((line) => line.isValid);

  /// Lines of the locked request (also when the cart was reopened).
  int get lockedLineCount => lockedRequest?.items.length ?? lines.length;
}
