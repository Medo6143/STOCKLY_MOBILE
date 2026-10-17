import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/features/invoices/domain/usecases/watch_invoice_processing_use_case.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_detail_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_list_notifier.dart';
import 'package:stockly/features/invoices/presentation/providers/invoice_processing_state.dart';
import 'package:stockly/features/invoices/presentation/providers/invoices_providers.dart';

/// Polls I3 every 2 s for up to 60 s while the AI reads the invoice
/// (contract I3). The poll stops when the provider is disposed. When the
/// invoice leaves `Processing`, the detail and the lists reload.
final class InvoiceProcessingNotifier extends Notifier<InvoiceProcessingState> {
  new(this.invoiceId);

  final String invoiceId;

  @override
  InvoiceProcessingState build() {
    final subscription = ref
        .watch(watchInvoiceProcessingUseCaseProvider)
        .call(invoiceId)
        .listen(_onPoll);
    ref.onDispose(subscription.cancel);
    return const InvoiceProcessingState();
  }

  /// Starts a new 60 s window (the manual refresh).
  void restart() => ref.invalidateSelf();

  void _onPoll(InvoicePoll poll) {
    switch (poll) {
      case InvoicePollFinished(:final invoice):
        state = InvoiceProcessingState(
          phase: InvoiceProcessingPhase.finished,
          invoice: invoice,
        );
        ref
          ..invalidate(invoiceListProvider)
          ..invalidate(invoiceDetailProvider(invoiceId));
      case InvoicePollProcessing(:final invoice):
        state = InvoiceProcessingState(invoice: invoice);
      case InvoicePollFailed(:final failure):
        state = state.copyWith(failure: failure);
      case InvoicePollTimedOut(:final lastFailure):
        state = lastFailure == null
            ? state.copyWith(
                phase: InvoiceProcessingPhase.stillProcessing,
                failure: null,
              )
            : state.copyWith(
                phase: InvoiceProcessingPhase.failed,
                failure: lastFailure,
              );
    }
  }
}

final NotifierProviderFamily<
  InvoiceProcessingNotifier,
  InvoiceProcessingState,
  String
>
invoiceProcessingProvider = NotifierProvider.autoDispose
    .family<InvoiceProcessingNotifier, InvoiceProcessingState, String>(
      InvoiceProcessingNotifier.new,
    );
