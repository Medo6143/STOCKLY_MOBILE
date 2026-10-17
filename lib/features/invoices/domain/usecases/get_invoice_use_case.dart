import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';

/// I3: one invoice with its lines.
final class GetInvoiceUseCase {
  const new(this._repository);

  final InvoicesRepository _repository;

  Future<Result<InvoiceDetail, Failure>> call(String invoiceId) =>
      _repository.getInvoice(invoiceId);
}
