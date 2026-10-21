import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/platform/external_browser.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/usecases/watch_payment_use_case.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/billing/presentation/providers/billing_refresh.dart';
import 'package:stockly/features/billing/presentation/providers/payment_status_state.dart';

/// Polls B4 every 3 s while the payment is `Pending` and the screen is
/// visible, up to the payment's `expiresAt` (plans-payments brief). Only
/// the server's status decides: the browser redirect never does. The
/// timer stops on a final status, on [pause] and when the provider is
/// disposed; [refresh] (app resumed, manual refresh) polls again. When the
/// payment reaches a final status, the plan, the history and the
/// dashboard reload.
final class PaymentStatusNotifier extends Notifier<PaymentStatusState> {
  new(this.paymentId);

  final String paymentId;
  StreamSubscription<PaymentPoll>? _subscription;

  @override
  PaymentStatusState build() {
    ref.onDispose(_stop);
    _start();
    return const PaymentStatusState();
  }

  /// Polls again from now, keeping what is shown.
  void refresh() {
    _stop();
    state = state.copyWith(polling: true);
    _start();
  }

  /// Stops polling while the app is in the background.
  void pause() {
    _stop();
    state = state.copyWith(polling: false);
  }

  /// B6 (Owner): gives up the pending payment.
  Future<void> cancel() async {
    if (state.cancelling) {
      return;
    }
    state = state.copyWith(cancelling: true, cancelFailure: null);
    final result = await ref.read(cancelPaymentUseCaseProvider).call(paymentId);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(value: final payment):
        _stop();
        state = state.copyWith(
          cancelling: false,
          payment: payment,
          polling: false,
        );
        invalidateBilling(ref);
      case Err(:final failure):
        state = state.copyWith(cancelling: false, cancelFailure: failure);
        refresh();
    }
  }

  /// Opens the hosted page of a pending card or wallet payment again, and
  /// says so when no browser took it.
  Future<void> openCheckout() async {
    final uri = state.payment?.openableCheckoutUrl;
    if (uri == null) {
      return;
    }
    // Cleared first so every failed tap is reported, not only the first.
    state = state.copyWith(pageNotOpened: false);
    final opened = await ref.read(externalBrowserProvider).open(uri);
    if (ref.mounted) {
      state = state.copyWith(pageNotOpened: !opened);
    }
  }

  void _start() {
    _subscription = ref
        .read(watchPaymentUseCaseProvider)
        .call(paymentId, now: ref.read(clockProvider).now())
        .listen(_onPoll);
  }

  void _stop() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _onPoll(PaymentPoll poll) {
    switch (poll) {
      case PaymentPollFinished(:final payment):
        final changed = state.payment?.status != payment.status;
        state = state.copyWith(payment: payment, failure: null, polling: false);
        if (changed) {
          invalidateBilling(ref);
        }
      case PaymentPollPending(:final payment):
        state = state.copyWith(payment: payment, failure: null);
      case PaymentPollFailed(:final failure):
        state = state.copyWith(failure: failure);
      case PaymentPollWindowEnded():
        state = state.copyWith(polling: false);
    }
  }
}

final NotifierProviderFamily<PaymentStatusNotifier, PaymentStatusState, String>
paymentStatusProvider = NotifierProvider.autoDispose
    .family<PaymentStatusNotifier, PaymentStatusState, String>(
      PaymentStatusNotifier.new,
    );
