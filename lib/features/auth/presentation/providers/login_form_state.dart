import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';

part 'login_form_state.freezed.dart';

/// The login form (design §11): loading while [isSubmitting], empty when
/// blank, error through [failure] and the field maps; success leaves the
/// screen.
@freezed
abstract class LoginFormState with _$LoginFormState {
  const factory({
    @Default(false) bool isSubmitting,

    /// Rejected on the device before sending.
    @Default(<AuthField, AuthFieldIssue>{})
    Map<AuthField, AuthFieldIssue> issues,

    /// `Validation.Failed` messages from the server, per field.
    @Default(<AuthField, List<String>>{})
    Map<AuthField, List<String>> serverErrors,

    /// A failure shown under one field (for example wrong credentials under
    /// the password).
    @Default(<AuthField, Failure>{}) Map<AuthField, Failure> fieldFailures,

    /// A failure shown in the banner above the form.
    Failure? failure,

    /// Time left of a `423 Auth.LockedOut`; the form stays usable.
    Duration? lockoutRemaining,

    /// Time left of a `429 Auth.TooManyRequests`; submit waits for it.
    Duration? retryAfterRemaining,
  }) = _LoginFormState;
}

extension LoginFormStateX on LoginFormState {
  bool get canSubmit => !isSubmitting && retryAfterRemaining == null;
}
