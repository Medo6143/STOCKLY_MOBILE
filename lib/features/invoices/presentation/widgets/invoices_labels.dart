import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/time/date_formatter.dart';
import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/core/widgets/ltr_isolate.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_input_rules.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_warning.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Exhaustive enum-to-text mappings of the invoice screens (design §8.3).

String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus status) =>
    switch (status) {
      InvoiceStatus.processing => l10n.invoicesStatusProcessing,
      InvoiceStatus.needsReview => l10n.invoicesStatusNeedsReview,
      InvoiceStatus.confirmed => l10n.invoicesStatusConfirmed,
      InvoiceStatus.failed => l10n.invoicesStatusFailed,
    };

String invoiceWarningLabel(AppLocalizations l10n, InvoiceWarning warning) =>
    switch (warning) {
      InvoiceWarning.totalMismatch => l10n.invoicesWarningTotalMismatch,
      InvoiceWarning.itemCapExceeded => l10n.invoicesWarningItemCapExceeded,
      InvoiceWarning.unreadableLines => l10n.invoicesWarningUnreadableLines,
      InvoiceWarning.duplicateInvoiceNumber =>
        l10n.invoicesWarningDuplicateInvoiceNumber,
    };

/// Number issues reuse the messages of the matching server codes, so the
/// user sees the same text whichever side catches it (design §5.3).
String invoiceFieldIssueLabel(AppLocalizations l10n, InvoiceFieldIssue issue) =>
    switch (issue) {
      InvoiceFieldIssue.required => l10n.invoicesFieldRequired,
      InvoiceFieldIssue.invalidNumber => l10n.invoicesFieldInvalidNumber,
      InvoiceFieldIssue.tooManyDecimals => l10n.errorPrecisionTooManyDecimals,
      InvoiceFieldIssue.negative => l10n.errorPrecisionNegative,
      InvoiceFieldIssue.notPositive => l10n.errorPrecisionNotPositive,
      InvoiceFieldIssue.outOfRange => l10n.errorPrecisionOutOfRange,
    };

/// The message of a queued scan's `lastErrorCode`: an API code or a local
/// failure reason (design §6.2).
String pendingScanErrorMessage(AppLocalizations l10n, String? code) {
  final apiCode = code == null ? null : ApiErrorCode.fromWire(code);
  if (apiCode != null) {
    return apiErrorMessage(l10n, apiCode);
  }
  final reason = LocalFailureReason.values.asNameMap()[code];
  return reason == null ? l10n.errorUnknown : localFailureMessage(l10n, reason);
}

/// The status line of a queued scan (design §6.4 "User sees").
String pendingScanStatusText(
  AppLocalizations l10n,
  PendingScan scan, {
  required bool online,
  required DateTime now,
  required String languageCode,
}) {
  final next = scan.nextAttemptAt;
  return switch (scan.status) {
    PendingScanStatus.queued =>
      online
          ? l10n.scanQueueStatusQueued
          : l10n.scanQueueStatusWaitingForInternet,
    PendingScanStatus.uploading => l10n.scanQueueStatusUploading,
    PendingScanStatus.waitingRetry when !online || next == null =>
      l10n.scanQueueStatusWaitingForInternet,
    PendingScanStatus.waitingRetry => l10n.scanQueueStatusWaitingRetry(
      ltrIsolate(DateFormatter.time(next!, languageCode)),
    ),
    PendingScanStatus.rateLimited => l10n.scanQueueStatusRateLimited(
      ltrIsolate('${_secondsUntil(next, now)}'),
    ),
    PendingScanStatus.quotaExceeded => l10n.scanQueueStatusQuotaExceeded,
    PendingScanStatus.failedPermanent => pendingScanErrorMessage(
      l10n,
      scan.lastErrorCode,
    ),
  };
}

/// Whole seconds until [next], at least 1.
int _secondsUntil(DateTime? next, DateTime now) {
  if (next == null) {
    return 1;
  }
  final remaining = next.difference(now);
  final seconds =
      (remaining.inMilliseconds + Duration.millisecondsPerSecond - 1) ~/
      Duration.millisecondsPerSecond;
  return seconds < 1 ? 1 : seconds;
}
