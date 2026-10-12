import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';

/// The request rules of contract A1 and A2, checked on the device so the
/// user sees mistakes before a round trip. The server checks them again.
abstract final class AuthInputRules {
  static const int emailMax = 256;
  static const int passwordMin = 8;
  static const int passwordMax = 128;
  static const int nameMax = 200;
  static const int phoneMax = 30;

  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Any letter, Latin or Arabic.
  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);
  static final RegExp _digit = RegExp(r'\p{Nd}', unicode: true);

  /// A2: both fields are required; formats are the server's business.
  static Map<AuthField, AuthFieldIssue> login({
    required String email,
    required String password,
  }) => {
    if (email.trim().isEmpty) AuthField.email: AuthFieldIssue.required,
    if (password.isEmpty) AuthField.password: AuthFieldIssue.required,
  };

  /// A1 request rules.
  static Map<AuthField, AuthFieldIssue> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    required String shopName,
    required ShopType? shopType,
    required String shopPhone,
    required String shopGovernorate,
    required String shopAddress,
  }) {
    final issues = <AuthField, AuthFieldIssue>{};
    void check(AuthField field, AuthFieldIssue? issue) {
      if (issue != null) {
        issues[field] = issue;
      }
    }

    check(AuthField.fullName, _required(fullName, nameMax));
    check(AuthField.email, _emailIssue(email));
    check(AuthField.password, _passwordIssue(password));
    check(AuthField.phone, _optional(phone, phoneMax));
    check(AuthField.shopName, _required(shopName, nameMax));
    if (shopType == null) {
      issues[AuthField.shopType] = AuthFieldIssue.required;
    }
    check(AuthField.shopPhone, _optional(shopPhone, phoneMax));
    check(AuthField.shopGovernorate, _optional(shopGovernorate, nameMax));
    check(AuthField.shopAddress, _optional(shopAddress, nameMax));
    return issues;
  }

  static AuthFieldIssue? _required(String value, int max) {
    if (value.trim().isEmpty) {
      return AuthFieldIssue.required;
    }
    return value.trim().length > max ? AuthFieldIssue.tooLong : null;
  }

  static AuthFieldIssue? _optional(String value, int max) =>
      value.trim().length > max ? AuthFieldIssue.tooLong : null;

  static AuthFieldIssue? _emailIssue(String value) {
    final email = value.trim();
    if (email.isEmpty) {
      return AuthFieldIssue.required;
    }
    if (email.length > emailMax) {
      return AuthFieldIssue.tooLong;
    }
    return _email.hasMatch(email) ? null : AuthFieldIssue.invalidEmail;
  }

  static AuthFieldIssue? _passwordIssue(String value) {
    if (value.isEmpty) {
      return AuthFieldIssue.required;
    }
    final valid =
        value.length >= passwordMin &&
        value.length <= passwordMax &&
        _letter.hasMatch(value) &&
        _digit.hasMatch(value);
    return valid ? null : AuthFieldIssue.weakPassword;
  }
}
