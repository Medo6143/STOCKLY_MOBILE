import 'package:freezed_annotation/freezed_annotation.dart';

part 'splash_state.freezed.dart';

/// The splash timing gate (design §10.2). Where to go is decided by the
/// router from the auth state; this only says when the splash may leave.
@freezed
abstract class SplashState with _$SplashState {
  const factory({
    /// The splash screen has started its timers.
    @Default(false) bool started,

    /// "Reduce motion" is on: the minimum does not apply (design §10.4).
    @Default(false) bool reducedMotion,

    /// `SplashTimings.minimum` has passed.
    @Default(false) bool minimumElapsed,

    /// `SplashTimings.maximum` has passed.
    @Default(false) bool maximumElapsed,
  }) = _SplashState;
}

extension SplashStateX on SplashState {
  /// The splash may leave as soon as the session is resolved.
  bool get finished =>
      started && (reducedMotion || minimumElapsed || maximumElapsed);
}
