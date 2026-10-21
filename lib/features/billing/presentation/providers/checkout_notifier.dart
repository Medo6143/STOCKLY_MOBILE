import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/platform/external_browser.dart';
import 'package:stockly/features/billing/domain/entities/checkout_request.dart';
import 'package:stockly/features/billing/domain/entities/payment.dart';
import 'package:stockly/features/billing/domain/entities/payment_method.dart';
import 'package:stockly/features/billing/domain/entities/wallet_phone_rules.dart';
import 'package:stockly/features/billing/presentation/providers/billing_providers.dart';
import 'package:stockly/features/billing/presentation/providers/billing_refresh.dart';
import 'package:stockly/features/billing/presentation/providers/checkout_state.dart';

/// The Owner's checkout of one plan (B3). An attempt's `clientRequestId`
/// is created on its first submit and sent again on every retry of the
/// same method and phone (rule 20); changing either, or opening the sheet
/// again, starts a new attempt with a new id. A card or wallet payment
/// opens the provider's hosted page; only B4 later says whether it was
/// paid.
final class CheckoutNotifier extends Notifier<CheckoutState> {
  new(this.planId);

  final String planId;

  /// Contract B3 request field of the wallet phone.
  static const String walletPhoneField = 'walletPhone';

  @override
  CheckoutState build() => const CheckoutState();

  void selectMethod(PaymentMethod method) {
    if (state.isSubmitting || method == state.method) {
      return;
    }
    state = state.copyWith(
      method: method,
      phoneIssue: null,
      phoneMessages: const [],
      failure: null,
      pendingPaymentId: null,
    );
  }

  /// The phone was edited: its errors go away.
  void phoneChanged() {
    if (state.phoneIssue != null || state.phoneMessages.isNotEmpty) {
      state = state.copyWith(phoneIssue: null, phoneMessages: const []);
    }
  }

  Future<void> submit({required String walletPhone}) async {
    if (state.isSubmitting) {
      return;
    }
    final method = state.method;
    String? phone;
    if (method == PaymentMethod.wallet) {
      final issue = WalletPhoneRules.check(walletPhone);
      if (issue != null) {
        state = state.copyWith(
          phoneIssue: issue,
          phoneMessages: const [],
          failure: null,
          pendingPaymentId: null,
        );
        return;
      }
      phone = WalletPhoneRules.normalize(walletPhone);
    }
    final last = state.lastRequest;
    final request =
        last != null &&
            last.sameAttemptAs(
              planId: planId,
              method: method,
              walletPhone: phone,
            )
        ? last
        : CheckoutRequest(
            clientRequestId: ref.read(uuidGeneratorProvider).v4(),
            planId: planId,
            method: method,
            walletPhone: phone,
          );
    state = state.copyWith(
      isSubmitting: true,
      lastRequest: request,
      phoneIssue: null,
      phoneMessages: const [],
      failure: null,
      pendingPaymentId: null,
    );
    final result = await ref.read(checkoutUseCaseProvider).call(request);
    if (!ref.mounted) {
      return;
    }
    switch (result) {
      case Ok(value: final payment):
        invalidateBilling(ref);
        // The payment exists now: show it first, so a browser that is slow
        // or never comes back cannot keep the sheet busy.
        final browser = ref.read(externalBrowserProvider);
        state = state.copyWith(isSubmitting: false, payment: payment);
        await _openHostedPage(browser, payment);
      case Err(:final ValidationFailure failure):
        final messages = failure.fieldErrors[walletPhoneField] ?? const [];
        state = state.copyWith(
          isSubmitting: false,
          phoneMessages: messages,
          failure: messages.isEmpty ? failure : null,
        );
      case Err(:final ApiFailure failure)
          when failure.code == ApiErrorCode.billingPaymentPending:
        state = state.copyWith(isSubmitting: false, failure: failure);
        await _findPendingPayment();
      case Err(:final failure):
        state = state.copyWith(isSubmitting: false, failure: failure);
    }
  }

  /// Opens the hosted page of a card or wallet payment. A browser that
  /// cannot be opened is not an error here: the status screen offers the
  /// page again and says when it does not open. [browser] is read before
  /// the state change, which may close the sheet and dispose this notifier.
  Future<void> _openHostedPage(ExternalBrowser browser, Payment payment) async {
    final uri = payment.openableCheckoutUrl;
    if (uri != null) {
      await browser.open(uri);
    }
  }

  /// The shop's pending payment (B2), for "Open the pending payment".
  Future<void> _findPendingPayment() async {
    final result = await ref.read(getSubscriptionUseCaseProvider).call();
    if (!ref.mounted) {
      return;
    }
    if (result case Ok(:final value)) {
      state = state.copyWith(pendingPaymentId: value.pendingPayment?.id);
    }
  }
}

final NotifierProviderFamily<CheckoutNotifier, CheckoutState, String>
checkoutProvider = NotifierProvider.autoDispose
    .family<CheckoutNotifier, CheckoutState, String>(CheckoutNotifier.new);
