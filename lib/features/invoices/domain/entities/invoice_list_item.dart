import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/decimal/money.dart';
import 'package:stockly/core/time/calendar_date.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_warning.dart';

part 'invoice_list_item.freezed.dart';

/// One row of the invoice list (contract `InvoiceListItem`).
@freezed
abstract class InvoiceListItem with _$InvoiceListItem {
  const factory({
    required String id,
    required InvoiceStatus status,
    required String? supplierName,
    required String? invoiceNumber,
    required CalendarDate? invoiceDate,
    required Money? totalAmount,
    required int itemCount,
    required List<InvoiceWarning> warnings,
    required DateTime createdAt,
  }) = _InvoiceListItem;
}
