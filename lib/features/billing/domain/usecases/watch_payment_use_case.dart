import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/billing/domain/entities/billing_timings.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/repositories/billing_repository.dart';

part 'watch_payment_use_case.freezed.dart';

/// One poll of a payment.
@freezed
sealed class PaymentPoll with _$PaymentPoll {
  /// The payment is `Paid`, `Failed` or `Expired`: polling is over.
  const factory finished(Payment payment) = PaymentPollFinished;

  /// Still `Pending`; polling goes on.
  const factory pending(Payment payment) = PaymentPollPending;

  /// This poll failed; polling goes on until the window ends.
  const factory failed(Failure failure) = PaymentPollFailed;

  /// The payment's `expiresAt` passed while it was still `Pending` (or
  /// the polls kept failing): polling stopped, a manual refresh asks
  /// again.
  const factory windowEnded() = PaymentPollWindowEnded;
}

/// B4 polled every [PaymentPolling.interval] while the payment is
/// `Pending`, up to its `expiresAt` (or [PaymentPolling.windowWithoutExpiry]
/// when it has none), counted from [call]'s `now`. Only the server's
/// status decides; cancelling the subscription stops the timer.
final class WatchPaymentUseCase {
  const new(this._repository);

  final BillingRepository _repository;

  Stream<PaymentPoll> call(String paymentId, {required DateTime now}) {
    late final StreamController<PaymentPoll> controller;
    Timer? timer;
    var cancelled = false;
    var polls = 0;
    var maxPolls = _pollsUntil(
      now.add(PaymentPolling.windowWithoutExpiry),
      now,
    );

    Future<void> poll() async {
      final result = await _repository.getPayment(paymentId);
      if (cancelled) {
        return;
      }
      polls++;
      switch (result) {
        case Ok(value: final payment) when payment.status.isFinal:
          controller.add(PaymentPoll.finished(payment));
          await controller.close();
          return;
        case Ok(value: final payment):
          final expiresAt = payment.expiresAt;
          if (expiresAt != null) {
            maxPolls = _pollsUntil(expiresAt, now);
          }
          controller.add(PaymentPoll.pending(payment));
        case Err(:final failure):
          controller.add(PaymentPoll.failed(failure));
      }
      if (polls > maxPolls) {
        controller.add(const PaymentPoll.windowEnded());
        await controller.close();
        return;
      }
      timer = Timer(PaymentPolling.interval, poll);
    }

    controller = StreamController<PaymentPoll>(
      onListen: poll,
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  /// Polls after the first one that fit between [now] and [end]; the last
  /// one runs at or just after [end].
  static int _pollsUntil(DateTime end, DateTime now) {
    final window = end.difference(now);
    if (window <= Duration.zero) {
      return 0;
    }
    final interval = PaymentPolling.interval.inMicroseconds;
    return (window.inMicroseconds + interval - 1) ~/ interval;
  }
}
