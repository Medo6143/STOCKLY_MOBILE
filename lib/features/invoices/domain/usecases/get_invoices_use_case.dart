import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_paging.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';

/// I2: one page of the invoice list ([InvoicePaging.pageSize] rows).
final class GetInvoicesUseCase {
  const new(this._repository);

  final InvoicesRepository _repository;

  Future<Result<Paged<InvoiceListItem>, Failure>> call(
    InvoiceStatus? status, {
    required int page,
  }) => _repository.getInvoices(
    status: status,
    page: page,
    pageSize: InvoicePaging.pageSize,
  );
}
