import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';

/// Where a submit failure of the login or register form is shown
/// (design §11). Chosen by failure type and `code`, never by the server's
/// `title` or `detail`.
final class AuthFormFailures {
  const new({
    this.serverErrors = const {},
    this.fieldFailures = const {},
    this.banner,
  });

  /// Splits [failure] into field messages and a banner.
  factory of(Failure failure) => switch (failure) {
    ValidationFailure(:final fieldErrors) => AuthFormFailures._validation(
      failure,
      fieldErrors,
    ),
    InvalidCredentialsFailure() => AuthFormFailures(
      fieldFailures: {AuthField.password: failure},
    ),
    ApiFailure(code: ApiErrorCode.authEmailTaken) => AuthFormFailures(
      fieldFailures: {AuthField.email: failure},
    ),
    ApiFailure(code: ApiErrorCode.shopNameRequired) => AuthFormFailures(
      fieldFailures: {AuthField.shopName: failure},
    ),
    ApiFailure(code: ApiErrorCode.shopUnknownType) => AuthFormFailures(
      fieldFailures: {AuthField.shopType: failure},
    ),
    _ => AuthFormFailures(banner: failure),
  };

  /// Field messages go under their field; a key that matches no field (or
  /// a failure without messages) shows the banner.
  factory _validation(
    ValidationFailure failure,
    Map<String, List<String>> fieldErrors,
  ) {
    final matched = <AuthField, List<String>>{};
    var unmatched = fieldErrors.isEmpty;
    for (final MapEntry(:key, :value) in fieldErrors.entries) {
      final field = wireFields[key];
      if (field == null) {
        unmatched = true;
      } else {
        matched[field] = value;
      }
    }
    return AuthFormFailures(
      serverErrors: matched,
      banner: unmatched ? failure : null,
    );
  }

  /// Contract A1/A2 request field names (camelCase, nested with dots).
  static const Map<String, AuthField> wireFields = {
    'email': AuthField.email,
    'password': AuthField.password,
    'fullName': AuthField.fullName,
    'phone': AuthField.phone,
    'shop.name': AuthField.shopName,
    'shop.shopType': AuthField.shopType,
    'shop.phone': AuthField.shopPhone,
    'shop.governorate': AuthField.shopGovernorate,
    'shop.address': AuthField.shopAddress,
  };

  final Map<AuthField, List<String>> serverErrors;
  final Map<AuthField, Failure> fieldFailures;
  final Failure? banner;
}
