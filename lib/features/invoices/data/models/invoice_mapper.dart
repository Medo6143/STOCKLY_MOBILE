import 'package:stockly/core/offline/app_database.dart' as db;
import 'package:stockly/core/offline/tables/pending_scans.dart' as db;
import 'package:stockly/features/invoices/data/models/invoice_dtos.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_warning.dart';
import 'package:stockly/features/invoices/domain/entities/new_product.dart';
import 'package:stockly/features/invoices/domain/entities/pending_scan.dart';

/// Contract enum strings of the invoice endpoints (§6).
abstract final class InvoiceWire {
  static const Map<String, InvoiceStatus> statuses = {
    'Processing': InvoiceStatus.processing,
    'NeedsReview': InvoiceStatus.needsReview,
    'Confirmed': InvoiceStatus.confirmed,
    'Failed': InvoiceStatus.failed,
  };

  static const Map<String, InvoiceWarning> warnings = {
    'TotalMismatch': InvoiceWarning.totalMismatch,
    'ItemCapExceeded': InvoiceWarning.itemCapExceeded,
    'UnreadableLines': InvoiceWarning.unreadableLines,
    'DuplicateInvoiceNumber': InvoiceWarning.duplicateInvoiceNumber,
  };

  /// The wire string of [status] (the I2 `status` query).
  static String statusName(InvoiceStatus status) =>
      statuses.entries.firstWhere((e) => e.value == status).key;

  /// Throws [FormatException] for a status the contract does not list.
  static InvoiceStatus status(String raw) =>
      statuses[raw] ?? (throw FormatException('Unknown invoice status', raw));

  /// Throws [FormatException] for a warning the contract does not list.
  static List<InvoiceWarning> warningsOf(List<String> raw) => [
    for (final value in raw)
      warnings[value] ?? (throw FormatException('Unknown warning', value)),
  ];
}

extension NewProductDtoMapper on NewProductDto {
  NewProduct toEntity() =>
      NewProduct(name: name, baseUnitName: baseUnitName, sellPrice: sellPrice);
}

extension NewProductMapper on NewProduct {
  NewProductDto toDto() => NewProductDto(
    name: name,
    baseUnitName: baseUnitName,
    sellPrice: sellPrice,
  );
}

extension InvoiceListItemDtoMapper on InvoiceListItemDto {
  InvoiceListItem toEntity() => InvoiceListItem(
    id: id,
    status: InvoiceWire.status(status),
    supplierName: supplierName,
    invoiceNumber: invoiceNumber,
    invoiceDate: invoiceDate,
    totalAmount: totalAmount,
    itemCount: itemCount,
    warnings: InvoiceWire.warningsOf(warnings),
    createdAt: createdAt,
  );
}

extension InvoiceItemDtoMapper on InvoiceItemDto {
  InvoiceItem toEntity() => InvoiceItem(
    id: id,
    lineNo: lineNo,
    rawName: rawName,
    productId: productId,
    productName: productName,
    productUnitId: productUnitId,
    unitName: unitName,
    quantity: quantity,
    unitPrice: unitPrice,
    lineTotal: lineTotal,
    expiryDate: expiryDate,
    batchNo: batchNo,
    matchConfidence: matchConfidence,
    newProduct: newProduct?.toEntity(),
  );
}

extension InvoiceDetailDtoMapper on InvoiceDetailDto {
  InvoiceDetail toEntity() => InvoiceDetail(
    id: id,
    clientRequestId: clientRequestId,
    status: InvoiceWire.status(status),
    supplierId: supplierId,
    supplierName: supplierName,
    invoiceNumber: invoiceNumber,
    invoiceDate: invoiceDate,
    totalAmount: totalAmount,
    computedTotal: computedTotal,
    warnings: InvoiceWire.warningsOf(warnings),
    failureReason: failureReason,
    items: [
      for (final item in [
        ...items,
      ]..sort((a, b) => a.lineNo.compareTo(b.lineNo)))
        item.toEntity(),
    ],
    createdAt: createdAt,
    processedAt: processedAt,
    confirmedAt: confirmedAt,
  );
}

extension InvoiceDraftMapper on InvoiceDraft {
  /// The I4 body: every line, `lineTotal` never sent.
  UpdateInvoiceItemsRequestDto toRequest() => UpdateInvoiceItemsRequestDto(
    supplierName: header.supplierName,
    invoiceNumber: header.invoiceNumber,
    invoiceDate: header.invoiceDate,
    totalAmount: header.totalAmount,
    items: [for (final line in lines) line.toRequest()],
  );
}

extension InvoiceLineDraftMapper on InvoiceLineDraft {
  UpdateInvoiceItemRequestDto toRequest() {
    final choice = this.choice;
    return UpdateInvoiceItemRequestDto(
      lineNo: lineNo,
      rawName: rawName,
      productId: choice is ExistingProductChoice ? choice.productId : null,
      productUnitId: choice is ExistingProductChoice
          ? choice.productUnitId
          : null,
      newProduct: choice is NewProductChoice ? choice.product.toDto() : null,
      quantity: quantity,
      unitPrice: unitPrice,
      expiryDate: expiryDate,
      batchNo: batchNo,
    );
  }
}

/// Database and domain names of the queue states are the same (design
/// §6.3), so they map by name.
extension PendingScanRowMapper on db.PendingScan {
  PendingScan toEntity() => PendingScan(
    clientRequestId: clientRequestId,
    status: PendingScanStatus.values.byName(status.name),
    imagePath: imagePath,
    imageSizeBytes: imageSizeBytes,
    attemptCount: attemptCount,
    nextAttemptAt: nextAttemptAt,
    lastErrorCode: lastErrorCode,
    capturedAt: capturedAt,
  );
}

extension PendingScanStatusMapper on db.PendingScanStatus {
  PendingScanStatus toEntity() => PendingScanStatus.values.byName(name);
}
