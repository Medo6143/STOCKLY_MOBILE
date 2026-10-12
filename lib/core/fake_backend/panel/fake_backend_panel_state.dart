import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/api_error_code.dart';

part 'fake_backend_panel_state.freezed.dart';

/// What the debug panel shows: the fake backend's runtime switches.
@freezed
abstract class FakeBackendPanelState with _$FakeBackendPanelState {
  const factory({
    required bool offline,
    required bool lockoutEnabled,
    required bool rateLimitEnabled,
    ApiErrorCode? failNextWith,
  }) = _FakeBackendPanelState;
}
