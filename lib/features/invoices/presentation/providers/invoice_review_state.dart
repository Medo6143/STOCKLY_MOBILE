import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';

part 'invoice_review_state.freezed.dart';

/// The review screen (design §11 review rules): the server's [invoice],
/// the editable [draft] and the save state.
@freezed
abstract class InvoiceReviewState with _$InvoiceReviewState {
  const factory({
    required InvoiceDetail invoice,
    required InvoiceDraft draft,
    @Default(false) bool isDirty,
    @Default(false) bool isSaving,

    /// I5 is running ("Confirming…" overlay).
    @Default(false) bool isConfirming,

    /// The last save's failure, shown in the banner.
    Failure? failure,

    /// Lines that need a product before saving
    /// (`Invoice.LineProductRequired`).
    @Default(<int>{}) Set<int> lineErrors,

    /// Server field messages per line (`items[i].field`), by `lineNo`.
    @Default(<int, List<String>>{}) Map<int, List<String>> lineMessages,

    /// The typed total that is not a valid amount.
    InvoiceFieldIssue? totalAmountIssue,

    /// Bumped by every successful save, so the screen can confirm it.
    @Default(0) int savedCount,

    /// Bumped when this screen's confirm succeeds, so the screen can move
    /// on to the confirmed invoice.
    @Default(0) int confirmedCount,
  }) = _InvoiceReviewState;
}

extension InvoiceReviewStateX on InvoiceReviewState {
  /// Only a `NeedsReview` invoice is edited (I4).
  bool get isReadOnly => !invoice.isEditable;

  bool get canSave =>
      !isReadOnly &&
      !isSaving &&
      !isConfirming &&
      draft.lines.isNotEmpty &&
      totalAmountIssue == null;

  /// Confirm saves a dirty draft first, so it needs what save needs.
  bool get canConfirm => canSave;

  /// Saving or confirming: the form is not editable.
  bool get isBusy => isSaving || isConfirming;
}
