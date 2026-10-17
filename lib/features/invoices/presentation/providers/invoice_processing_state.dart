import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/invoices/domain/entities/invoice_detail.dart';

part 'invoice_processing_state.freezed.dart';

/// Where the wait for the AI extraction stands (design §11).
enum InvoiceProcessingPhase {
  /// Polling every 2 s (failed polls included, until the window ends).
  polling,

  /// The invoice left `Processing`: [InvoiceProcessingState.invoice].
  finished,

  /// 60 s passed and the invoice is still `Processing`.
  stillProcessing,

  /// 60 s passed and the last poll failed:
  /// [InvoiceProcessingState.failure].
  failed,
}

@freezed
abstract class InvoiceProcessingState with _$InvoiceProcessingState {
  const factory({
    @Default(InvoiceProcessingPhase.polling) InvoiceProcessingPhase phase,
    InvoiceDetail? invoice,
    Failure? failure,
  }) = _InvoiceProcessingState;
}
