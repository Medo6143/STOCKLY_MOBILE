import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_paging.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_status.dart';
import 'package:stockly/features/invoices/domain/repositories/invoices_repository.dart';

part 'watch_invoice_processing_use_case.freezed.dart';

/// One poll of an invoice that the AI is reading.
@freezed
sealed class InvoicePoll with _$InvoicePoll {
  /// The invoice left `Processing`: polling is over.
  const factory finished(InvoiceDetail invoice) = InvoicePollFinished;

  /// Still `Processing`; polling goes on.
  const factory processing(InvoiceDetail invoice) = InvoicePollProcessing;

  /// This poll failed; polling goes on until the window ends.
  const factory failed(Failure failure) = InvoicePollFailed;

  /// The window ended. [lastFailure] is set when the last poll failed.
  const factory timedOut({Failure? lastFailure}) = InvoicePollTimedOut;
}

/// I3 polled every [InvoicePolling.interval] for up to
/// [InvoicePolling.window] while the invoice is `Processing` (contract I3).
/// Cancelling the subscription stops the timer.
final class WatchInvoiceProcessingUseCase {
  const new(this._repository);

  final InvoicesRepository _repository;

  Stream<InvoicePoll> call(String invoiceId) {
    late final StreamController<InvoicePoll> controller;
    Timer? timer;
    var cancelled = false;
    var polls = 0;
    Failure? lastFailure;

    Future<void> poll() async {
      final result = await _repository.getInvoice(invoiceId);
      if (cancelled) {
        return;
      }
      polls++;
      switch (result) {
        case Ok(value: final invoice)
            when invoice.status != InvoiceStatus.processing:
          controller.add(InvoicePoll.finished(invoice));
          await controller.close();
          return;
        case Ok(value: final invoice):
          lastFailure = null;
          controller.add(InvoicePoll.processing(invoice));
        case Err(:final failure):
          lastFailure = failure;
          controller.add(InvoicePoll.failed(failure));
      }
      if (polls > InvoicePolling.maxRepeats) {
        controller.add(InvoicePoll.timedOut(lastFailure: lastFailure));
        await controller.close();
        return;
      }
      timer = Timer(InvoicePolling.interval, poll);
    }

    controller = StreamController<InvoicePoll>(
      onListen: poll,
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}
