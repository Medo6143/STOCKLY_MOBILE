import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';

/// I5: confirms the reviewed invoice, which receives the stock. Safe to
/// retry: a repeat returns the confirmed invoice and changes nothing.
final class ConfirmInvoiceUseCase {
  const new(this._repository);

  final InvoicesRepository _repository;

  Future<Result<InvoiceDetail, Failure>> call(String invoiceId) =>
      _repository.confirm(invoiceId);
}
