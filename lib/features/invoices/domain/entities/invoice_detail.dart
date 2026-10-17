import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_warning.dart';

part 'invoice_detail.freezed.dart';

/// One invoice with its lines by `lineNo` (contract `InvoiceDetail`).
@freezed
abstract class InvoiceDetail with _$InvoiceDetail {
  const factory({
    required String id,
    required String clientRequestId,
    required InvoiceStatus status,
    required String? supplierId,
    required String? supplierName,
    required String? invoiceNumber,
    required CalendarDate? invoiceDate,
    required Money? totalAmount,
    required Money? computedTotal,
    required List<InvoiceWarning> warnings,
    required String? failureReason,
    required List<InvoiceItem> items,
    required DateTime createdAt,
    required DateTime? processedAt,
    required DateTime? confirmedAt,
  }) = _InvoiceDetail;
}

extension InvoiceDetailX on InvoiceDetail {
  /// Lines are editable only while the invoice waits for review (I4).
  bool get isEditable => status == InvoiceStatus.needsReview;
}
