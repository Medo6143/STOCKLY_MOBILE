import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/pagination/paged.dart';
import 'package:stockly/core/pagination/paged_notifier.dart';
import 'package:stockly/core/pagination/paged_state.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_list_item.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';
import 'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart';

/// The invoice list for one status filter (I2), page by page. It reloads
/// when a queued scan leaves the queue, because an upload adds an invoice
/// (design §2.3).
final class InvoiceListNotifier extends PagedNotifier<InvoiceListItem> {
  new(this.status);

  /// `null` lists every status.
  final InvoiceStatus? status;

  @override
  Future<PagedState<InvoiceListItem>> build() {
    ref.listen(pendingScanCountProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      if (before != null && after != null && after < before) {
        ref.invalidateSelf();
      }
    });
    return super.build();
  }

  @override
  Future<Result<Paged<InvoiceListItem>, Failure>> fetchPage(int page) =>
      ref.read(getInvoicesUseCaseProvider).call(status, page: page);
}

final AsyncNotifierProviderFamily<
  InvoiceListNotifier,
  PagedState<InvoiceListItem>,
  InvoiceStatus?
>
invoiceListProvider = AsyncNotifierProvider.autoDispose
    .family<InvoiceListNotifier, PagedState<InvoiceListItem>, InvoiceStatus?>(
      InvoiceListNotifier.new,
    );
