import 'package:stockly/core/widgets/failure_message.dart';
import 'package:stockly/features/products/domain/entities/product_field.dart';
import 'package:stockly/features/products/domain/entities/stock_movement_reason.dart';
import 'package:stockly/features/products/presentation/providers/product_form_errors.dart';
import 'package:stockly/l10n/generated/app_localizations.dart';

/// Exhaustive enum-to-text mappings of the product screens (design §8.3).

String movementReasonLabel(AppLocalizations l10n, StockMovementReason reason) =>
    switch (reason) {
      StockMovementReason.invoiceReceipt => l10n.movementReasonInvoiceReceipt,
      StockMovementReason.sale => l10n.movementReasonSale,
      StockMovementReason.manualAdjustment =>
        l10n.movementReasonManualAdjustment,
      StockMovementReason.stockCount => l10n.movementReasonStockCount,
      StockMovementReason.invoiceReversal => l10n.movementReasonInvoiceReversal,
    };

/// Number issues reuse the messages of the matching server codes, so the
/// user sees the same text whichever side catches it (design §5.3).
String productFieldIssueLabel(AppLocalizations l10n, ProductFieldIssue issue) =>
    switch (issue) {
      ProductFieldIssue.required => l10n.productsFieldRequired,
      ProductFieldIssue.tooLong => l10n.productsFieldTooLong,
      ProductFieldIssue.invalidNumber => l10n.productsFieldInvalidNumber,
      ProductFieldIssue.tooManyDecimals => l10n.errorPrecisionTooManyDecimals,
      ProductFieldIssue.negative => l10n.errorPrecisionNegative,
      ProductFieldIssue.notPositive => l10n.errorPrecisionNotPositive,
      ProductFieldIssue.zero => l10n.errorStockZeroChange,
      ProductFieldIssue.outOfRange => l10n.errorPrecisionOutOfRange,
    };

/// The message under [field]: a device check first, then the server's
/// field message, then a failure that belongs to the field.
String? productFieldError(
  AppLocalizations l10n,
  ProductField field,
  ProductFormErrors errors,
) {
  final issue = errors.issues[field];
  if (issue != null) {
    return productFieldIssueLabel(l10n, issue);
  }
  final server = errors.serverErrors[field];
  if (server != null && server.isNotEmpty) {
    return server.join('\n');
  }
  final failure = errors.fieldFailures[field];
  return failure == null ? null : failureMessage(l10n, failure);
}
