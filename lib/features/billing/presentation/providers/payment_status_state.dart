import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';

part 'payment_status_state.freezed.dart';

/// One payment as the polls see it (plans-payments brief).
@freezed
abstract class PaymentStatusState with _$PaymentStatusState {
  const factory({
    /// The latest answer of B4.
    Payment? payment,

    /// The last poll failed (cleared by the next good one).
    Failure? failure,

    /// B4 is being polled every 3 s.
    @Default(true) bool polling,

    /// B6 is running.
    @Default(false) bool cancelling,

    /// The last cancel failed (`Billing.NotCancelable`, network, ...).
    Failure? cancelFailure,
  }) = _PaymentStatusState;
}

extension PaymentStatusStateX on PaymentStatusState {
  /// The four states of the screen: loading until the first answer, an
  /// error when the first answer failed, else the payment.
  AsyncValue<Payment> get view {
    final payment = this.payment;
    final failure = this.failure;
    if (payment != null) {
      return AsyncData(payment);
    }
    return failure != null
        ? AsyncError(failure, StackTrace.empty)
        : const AsyncLoading();
  }

  /// Still `Pending` but no longer polled: a manual refresh asks again.
  bool get waitingWithoutPolling => !polling && (payment?.isPending ?? false);
}
