import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/fake_backend/fake_backend_adapter.dart';
import 'package:stockly/core/fake_backend/fake_backend_provider.dart';
import 'package:stockly/core/fake_backend/panel/fake_backend_panel_state.dart';

/// Flips the fake backend's switches (design §12.1). Fake mode only: the
/// panel is never shown when [fakeBackendProvider] is `null`.
final class FakeBackendPanelNotifier extends Notifier<FakeBackendPanelState> {
  @override
  FakeBackendPanelState build() {
    final controls = _adapter.controls;
    return FakeBackendPanelState(
      offline: controls.offline,
      lockoutEnabled: controls.lockoutEnabled,
      rateLimitEnabled: controls.rateLimitEnabled,
      scanQuotaExhausted: controls.scanQuotaExhausted,
      failNextWith: controls.failNextWith,
    );
  }

  FakeBackendAdapter get _adapter => ref.read(fakeBackendProvider)!;

  void setOffline({required bool offline}) {
    _adapter.controls.offline = offline;
    state = state.copyWith(offline: offline);
  }

  void failNextWith(ApiErrorCode? code) {
    _adapter.controls.failNextWith = code;
    state = state.copyWith(failNextWith: code);
  }

  void setLockout({required bool enabled}) {
    _adapter.controls.lockoutEnabled = enabled;
    state = state.copyWith(lockoutEnabled: enabled);
  }

  void setRateLimit({required bool enabled}) {
    _adapter.controls.rateLimitEnabled = enabled;
    state = state.copyWith(rateLimitEnabled: enabled);
  }

  void setScanQuotaExhausted({required bool exhausted}) {
    _adapter.controls.scanQuotaExhausted = exhausted;
    state = state.copyWith(scanQuotaExhausted: exhausted);
  }

  void expireAccessToken() => _adapter.expireAccessTokens();

  void suspendShop(String shopId) =>
      _adapter.setShopSuspended(shopId, suspended: true);

  /// The fake provider reports [paymentId] as paid or failed.
  bool settlePayment(String paymentId, {required bool paid}) =>
      _adapter.settlePayment(paymentId, paid: paid);
}

final NotifierProvider<FakeBackendPanelNotifier, FakeBackendPanelState>
fakeBackendPanelProvider =
    NotifierProvider.autoDispose<
      FakeBackendPanelNotifier,
      FakeBackendPanelState
    >(FakeBackendPanelNotifier.new);
