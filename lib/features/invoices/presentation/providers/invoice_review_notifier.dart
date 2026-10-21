import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/line_field_errors.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_detail_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_list_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_review_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';
import 'package:stockly/features/products/presentation/providers/product_list_notifier.dart';

/// Review of one invoice (design §11 review rules): loads I3, keeps the
/// edited draft in memory, saves it with I4 and confirms it with I5 (a
/// dirty draft is saved first). The server's answer replaces the draft.
final class InvoiceReviewNotifier extends AsyncNotifier<InvoiceReviewState> {
  new(this.invoiceId);

  final String invoiceId;

  @override
  Future<InvoiceReviewState> build() async {
    final invoice =
        await (await ref.watch(getInvoiceUseCaseProvider).call(invoiceId))
            .toFuture();
    return _fresh(invoice);
  }

  InvoiceReviewState _fresh(InvoiceDetail invoice) => InvoiceReviewState(
    invoice: invoice,
    draft: InvoiceDraft.fromDetail(invoice),
  );

  void _edit(InvoiceReviewState Function(InvoiceReviewState current) change) {
    final current = state.value;
    if (current == null || current.isReadOnly || current.isBusy) {
      return;
    }
    state = AsyncData(change(current).copyWith(isDirty: true));
  }

  void setSupplierName(String value) =>
      _edit((s) => s.copyWith.draft.header(supplierName: _blankToNull(value)));

  void setInvoiceNumber(String value) =>
      _edit((s) => s.copyWith.draft.header(invoiceNumber: _blankToNull(value)));

  void setInvoiceDate(CalendarDate? value) =>
      _edit((s) => s.copyWith.draft.header(invoiceDate: value));

  /// Parses the typed total (`>= 0`, 2 decimals); blank clears it.
  void setTotalAmount(String text) {
    final parsed = InvoiceInputRules.optionalMoney(text);
    _edit(
      (s) => parsed.issue == null
          ? s
                .copyWith(totalAmountIssue: null)
                .copyWith
                .draft
                .header(totalAmount: parsed.value)
          : s.copyWith(totalAmountIssue: parsed.issue),
    );
  }

  /// Puts an edited or new line into the draft (the line editor).
  void putLine(InvoiceLineDraft line) => _edit(
    (s) => s.copyWith(
      draft: s.draft.withLine(line),
      lineErrors: {...s.lineErrors}..remove(line.lineNo),
      lineMessages: {...s.lineMessages}..remove(line.lineNo),
    ),
  );

  void removeLine(int lineNo) => _edit(
    (s) => s.copyWith(
      draft: s.draft.withoutLine(lineNo),
      lineErrors: {...s.lineErrors}..remove(lineNo),
      lineMessages: {...s.lineMessages}..remove(lineNo),
    ),
  );

  /// Saves the whole draft with I4. Lines without a product are flagged
  /// first; nothing is sent while one exists.
  Future<void> save() async {
    final current = state.value;
    if (current == null || !current.canSave) {
      return;
    }
    final unresolved = current.draft.unresolvedLineNos;
    if (unresolved.isNotEmpty) {
      state = AsyncData(
        current.copyWith(lineErrors: unresolved.toSet(), failure: null),
      );
      return;
    }
    state = AsyncData(
      current.copyWith(
        isSaving: true,
        failure: null,
        lineErrors: const {},
        lineMessages: const {},
      ),
    );
    final sent = current.draft;
    final result = await ref
        .read(saveInvoiceItemsUseCaseProvider)
        .call(invoiceId, sent);
    if (!ref.mounted) {
      return;
    }
    final latest = state.value ?? current;
    switch (result) {
      case Ok(value: final invoice):
        ref
          ..invalidate(invoiceListProvider)
          ..invalidate(invoiceDetailProvider(invoiceId));
        state = AsyncData(
          _fresh(invoice).copyWith(savedCount: latest.savedCount + 1),
        );
      case Err(:final failure):
        state = AsyncData(await _afterFailure(latest, failure, sent));
    }
  }

  /// Confirms the invoice with I5 (design §11 Sprint 4): a dirty draft is
  /// saved first and nothing is confirmed when that save fails. Lines
  /// without a product are flagged on the device. Retrying is safe: the
  /// server returns a confirmed invoice unchanged.
  Future<void> confirm() async {
    var current = state.value;
    if (current == null || !current.canConfirm) {
      return;
    }
    if (current.isDirty) {
      await save();
      current = state.value;
      if (!ref.mounted ||
          current == null ||
          current.isDirty ||
          current.failure != null ||
          current.lineErrors.isNotEmpty) {
        return;
      }
    }
    final unresolved = current.draft.unresolvedLineNos;
    if (unresolved.isNotEmpty) {
      state = AsyncData(
        current.copyWith(lineErrors: unresolved.toSet(), failure: null),
      );
      return;
    }
    state = AsyncData(
      current.copyWith(
        isConfirming: true,
        failure: null,
        lineErrors: const {},
        lineMessages: const {},
      ),
    );
    final result = await ref
        .read(confirmInvoiceUseCaseProvider)
        .call(invoiceId);
    if (!ref.mounted) {
      return;
    }
    final latest = state.value ?? current;
    switch (result) {
      case Ok(value: final invoice):
        ref
          ..invalidate(invoiceListProvider)
          ..invalidate(invoiceDetailProvider(invoiceId))
          ..invalidate(productListProvider)
          ..invalidate(dashboardSummaryProvider);
        state = AsyncData(
          _fresh(invoice).copyWith(
            savedCount: latest.savedCount,
            confirmedCount: latest.confirmedCount + 1,
          ),
        );
      case Err(:final failure):
        state = AsyncData(
          await _afterFailure(
            latest.copyWith(isConfirming: false),
            failure,
            latest.draft,
          ),
        );
    }
  }

  Future<InvoiceReviewState> _afterFailure(
    InvoiceReviewState latest,
    Failure failure,
    InvoiceDraft sent,
  ) async {
    final failed = latest.copyWith(isSaving: false, failure: failure);
    switch (failure) {
      case ValidationFailure(:final fieldErrors):
        return failed.copyWith(
          lineMessages: LineFieldErrors.byLine(fieldErrors, [
            for (final line in sent.lines) line.lineNo,
          ]),
        );
      case ApiFailure(code: ApiErrorCode.invoiceLineProductRequired):
        return failed.copyWith(lineErrors: sent.unresolvedLineNos.toSet());
      case ApiFailure(
        code: ApiErrorCode.invoiceNotEditable ||
            ApiErrorCode.invoiceNotConfirmable,
      ):
        // The invoice moved on (for example confirmed elsewhere): show it
        // as it is now, read-only.
        final reloaded = await ref
            .read(getInvoiceUseCaseProvider)
            .call(invoiceId);
        return switch (reloaded) {
          Ok(value: final invoice) => _fresh(
            invoice,
          ).copyWith(failure: failure, savedCount: latest.savedCount),
          Err() => failed,
        };
      case _:
        return failed;
    }
  }

  static String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final AsyncNotifierProviderFamily<
  InvoiceReviewNotifier,
  InvoiceReviewState,
  String
>
invoiceReviewProvider = AsyncNotifierProvider.autoDispose
    .family<InvoiceReviewNotifier, InvoiceReviewState, String>(
      InvoiceReviewNotifier.new,
    );
