import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_out_state.freezed.dart';

/// Sign out from settings or the suspended screen. It never fails for the
/// user: the local session is cleared even when the server cannot be
/// reached.
@freezed
abstract class SignOutState with _$SignOutState {
  const factory({@Default(false) bool inProgress}) = _SignOutState;
}
