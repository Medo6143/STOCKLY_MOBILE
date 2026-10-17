import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/match_confidence.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/decimal/quantity.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_item.dart';
import 'package:stockly/features/invoices/domain/entities/new_product.dart';

part 'invoice_draft.freezed.dart';

/// Contract I4 limits.
abstract final class InvoiceRules {
  /// At most this many lines per invoice.
  static const int maxLines = 100;
}

/// What a line points at (design §11 review rules): an existing product
/// and one of its units, a product created on confirm, or nothing yet.
@freezed
sealed class LineProductChoice with _$LineProductChoice {
  const factory existing({
    required String productId,
    required String productUnitId,
    required String productName,
    required String unitName,
  }) = ExistingProductChoice;

  const factory newProduct(NewProduct product) = NewProductChoice;

  const factory unresolved() = UnresolvedChoice;
}

/// One line of the review draft. [lineTotal] and [matchConfidence] are the
/// server's values; an edited line has none until it is saved.
@freezed
abstract class InvoiceLineDraft with _$InvoiceLineDraft {
  const factory({
    required int lineNo,
    required String rawName,
    required LineProductChoice choice,
    required Quantity quantity,
    required Money unitPrice,
    CalendarDate? expiryDate,
    String? batchNo,
    Money? lineTotal,
    MatchConfidence? matchConfidence,
  }) = _InvoiceLineDraft;

  /// Existing product when both ids are set, else the new product, else
  /// unresolved.
  factory fromItem(InvoiceItem item) {
    final productId = item.productId;
    final unitId = item.productUnitId;
    final newProduct = item.newProduct;
    return InvoiceLineDraft(
      lineNo: item.lineNo,
      rawName: item.rawName,
      choice: productId != null && unitId != null
          ? LineProductChoice.existing(
              productId: productId,
              productUnitId: unitId,
              productName: item.productName ?? '',
              unitName: item.unitName ?? '',
            )
          : newProduct != null
          ? LineProductChoice.newProduct(newProduct)
          : const LineProductChoice.unresolved(),
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      expiryDate: item.expiryDate,
      batchNo: item.batchNo,
      lineTotal: item.lineTotal,
      matchConfidence: item.matchConfidence,
    );
  }
}

/// The header fields of I4.
@freezed
abstract class InvoiceHeaderDraft with _$InvoiceHeaderDraft {
  const factory({
    String? supplierName,
    String? invoiceNumber,
    CalendarDate? invoiceDate,
    Money? totalAmount,
  }) = _InvoiceHeaderDraft;
}

/// The editable copy of an invoice: header and every line (design §11).
@freezed
abstract class InvoiceDraft with _$InvoiceDraft {
  const factory({
    required InvoiceHeaderDraft header,
    required List<InvoiceLineDraft> lines,
  }) = _InvoiceDraft;

  /// The draft of [detail], lines by `lineNo`.
  factory fromDetail(InvoiceDetail detail) => InvoiceDraft(
    header: InvoiceHeaderDraft(
      supplierName: detail.supplierName,
      invoiceNumber: detail.invoiceNumber,
      invoiceDate: detail.invoiceDate,
      totalAmount: detail.totalAmount,
    ),
    lines: [
      for (final item in [
        ...detail.items,
      ]..sort((a, b) => a.lineNo.compareTo(b.lineNo)))
        InvoiceLineDraft.fromItem(item),
    ],
  );
}

extension InvoiceDraftX on InvoiceDraft {
  /// The `lineNo` of a new line: the highest one plus one.
  int get nextLineNo =>
      lines.isEmpty ? 1 : lines.map((l) => l.lineNo).reduce(max) + 1;

  /// `false` at [InvoiceRules.maxLines] lines.
  bool get canAddLine => lines.length < InvoiceRules.maxLines;

  InvoiceLineDraft? lineByNo(int lineNo) {
    for (final line in lines) {
      if (line.lineNo == lineNo) {
        return line;
      }
    }
    return null;
  }

  /// [line] replacing the line with its `lineNo`, or appended as a new
  /// line while under [InvoiceRules.maxLines].
  InvoiceDraft withLine(InvoiceLineDraft line) {
    if (lineByNo(line.lineNo) != null) {
      return copyWith(
        lines: [
          for (final current in lines)
            if (current.lineNo == line.lineNo) line else current,
        ],
      );
    }
    return canAddLine ? copyWith(lines: [...lines, line]) : this;
  }

  InvoiceDraft withoutLine(int lineNo) =>
      copyWith(lines: [...lines.where((l) => l.lineNo != lineNo)]);

  /// Lines with neither a product nor a new product
  /// (`Invoice.LineProductRequired`).
  List<int> get unresolvedLineNos => [
    for (final line in lines)
      if (line.choice is UnresolvedChoice) line.lineNo,
  ];
}
