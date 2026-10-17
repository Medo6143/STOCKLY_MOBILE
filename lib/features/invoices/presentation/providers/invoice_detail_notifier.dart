import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';

/// One invoice (I3); the detail screen routes on its status.
final class InvoiceDetailNotifier extends AsyncNotifier<InvoiceDetail> {
  new(this.invoiceId);

  final String invoiceId;

  @override
  Future<InvoiceDetail> build() => ref
      .watch(getInvoiceUseCaseProvider)
      .call(invoiceId)
      .then((result) => result.toFuture());
}

final AsyncNotifierProviderFamily<InvoiceDetailNotifier, InvoiceDetail, String>
invoiceDetailProvider = AsyncNotifierProvider.autoDispose
    .family<InvoiceDetailNotifier, InvoiceDetail, String>(
      InvoiceDetailNotifier.new,
    );
