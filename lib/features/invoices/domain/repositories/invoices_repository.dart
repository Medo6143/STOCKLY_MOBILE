import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';

/// Contract I2–I5. Uploads (I1) go through the scan queue.
abstract interface class InvoicesRepository {
  /// I2, newest first; [status] `null` lists every status.
  Future<Result<Paged<InvoiceListItem>, Failure>> getInvoices({
    required InvoiceStatus? status,
    required int page,
    required int pageSize,
  });

  /// I3.
  Future<Result<InvoiceDetail, Failure>> getInvoice(String invoiceId);

  /// I4: replaces the header and every line.
  Future<Result<InvoiceDetail, Failure>> saveItems(
    String invoiceId,
    InvoiceDraft draft,
  );

  /// I5: receives the stock of every line. Idempotent: a confirmed
  /// invoice comes back unchanged.
  Future<Result<InvoiceDetail, Failure>> confirm(String invoiceId);
}
