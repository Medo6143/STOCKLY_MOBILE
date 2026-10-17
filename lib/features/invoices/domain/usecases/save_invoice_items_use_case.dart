import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';

/// I4: saves the header and all lines of the draft. The server's answer
/// (line totals, warnings) replaces the draft.
final class SaveInvoiceItemsUseCase {
  const new(this._repository);

  final InvoicesRepository _repository;

  Future<Result<InvoiceDetail, Failure>> call(
    String invoiceId,
    InvoiceDraft draft,
  ) => _repository.saveItems(invoiceId, draft);
}
