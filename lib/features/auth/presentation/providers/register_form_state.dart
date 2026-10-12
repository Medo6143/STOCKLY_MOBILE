import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';

part 'register_form_state.freezed.dart';

/// The register form (design §11): loading while [isSubmitting], empty when
/// blank, error through [failure] and the field maps; success leaves the
/// screen.
@freezed
abstract class RegisterFormState with _$RegisterFormState {
  const factory({
    ShopType? shopType,
    @Default(false) bool isSubmitting,
    @Default(<AuthField, AuthFieldIssue>{})
    Map<AuthField, AuthFieldIssue> issues,
    @Default(<AuthField, List<String>>{})
    Map<AuthField, List<String>> serverErrors,
    @Default(<AuthField, Failure>{}) Map<AuthField, Failure> fieldFailures,
    Failure? failure,

    /// Time left of a `429 Auth.TooManyRequests`; submit waits for it.
    Duration? retryAfterRemaining,
  }) = _RegisterFormState;
}

extension RegisterFormStateX on RegisterFormState {
  bool get canSubmit => !isSubmitting && retryAfterRemaining == null;
}
