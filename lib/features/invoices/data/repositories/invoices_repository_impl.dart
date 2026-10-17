import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/paged_response_dto.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:stockly/features/invoices/data/models/invoice_mapper.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_draft.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';

final class InvoicesRepositoryImpl implements InvoicesRepository {
  const new(this._remote);

  final InvoicesRemoteDataSource _remote;

  @override
  Future<Result<Paged<InvoiceListItem>, Failure>> getInvoices({
    required InvoiceStatus? status,
    required int page,
    required int pageSize,
  }) => safeApiCall(() async {
    final response = await _remote.getInvoices(
      status: status == null ? null : InvoiceWire.statusName(status),
      page: page,
      pageSize: pageSize,
    );
    return response.toPaged((item) => item.toEntity());
  });

  @override
  Future<Result<InvoiceDetail, Failure>> getInvoice(String invoiceId) =>
      safeApiCall(() async => (await _remote.getInvoice(invoiceId)).toEntity());

  @override
  Future<Result<InvoiceDetail, Failure>> saveItems(
    String invoiceId,
    InvoiceDraft draft,
  ) => safeApiCall(
    () async =>
        (await _remote.updateItems(invoiceId, draft.toRequest())).toEntity(),
  );
}
