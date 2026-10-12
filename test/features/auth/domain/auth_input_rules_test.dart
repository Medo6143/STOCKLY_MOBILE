import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/features/auth/domain/entities/auth_field.dart';
import 'package:stockly/features/auth/domain/entities/auth_input_rules.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';

Map<AuthField, AuthFieldIssue> _register({
  String fullName = 'Mona Adel',
  String email = 'mona@example.com',
  String password = 'Str0ngPass',
  String phone = '',
  String shopName = 'صيدلية الشفاء',
  ShopType? shopType = ShopType.pharmacy,
  String shopPhone = '',
  String shopGovernorate = '',
  String shopAddress = '',
}) => AuthInputRules.register(
  fullName: fullName,
  email: email,
  password: password,
  phone: phone,
  shopName: shopName,
  shopType: shopType,
  shopPhone: shopPhone,
  shopGovernorate: shopGovernorate,
  shopAddress: shopAddress,
);

void main() {
  group('login', () {
    test('login_BothFilled_NoIssues', () {
      expect(AuthInputRules.login(email: 'a@b.c', password: 'x'), isEmpty);
    });

    test('login_BlankFields_Required', () {
      expect(AuthInputRules.login(email: '  ', password: ''), {
        AuthField.email: AuthFieldIssue.required,
        AuthField.password: AuthFieldIssue.required,
      });
    });
  });

  group('register (contract A1)', () {
    test('register_ContractExample_NoIssues', () {
      expect(_register(), isEmpty);
    });

    test('register_RequiredFieldsMissing_Required', () {
      expect(
        _register(
          fullName: ' ',
          email: '',
          password: '',
          shopName: '',
          shopType: null,
        ),
        {
          AuthField.fullName: AuthFieldIssue.required,
          AuthField.email: AuthFieldIssue.required,
          AuthField.password: AuthFieldIssue.required,
          AuthField.shopName: AuthFieldIssue.required,
          AuthField.shopType: AuthFieldIssue.required,
        },
      );
    });

    test('register_BadEmail_InvalidEmail', () {
      for (final email in ['mona', 'mona@', 'mona@example', 'a b@c.d']) {
        expect(
          _register(email: email)[AuthField.email],
          AuthFieldIssue.invalidEmail,
          reason: email,
        );
      }
    });

    test('register_PasswordRules_LetterDigitAnd8To128', () {
      for (final password in [
        'Sh0rt',
        'NoDigitsHere',
        '12345678',
        'a1${'x' * 127}',
      ]) {
        expect(
          _register(password: password)[AuthField.password],
          AuthFieldIssue.weakPassword,
          reason: password,
        );
      }
      expect(_register(password: 'كلمةسر123'), isEmpty);
      expect(_register(password: 'a1${'x' * 126}'), isEmpty);
    });

    test('register_TooLong_TooLong', () {
      expect(
        _register(
          fullName: 'x' * 201,
          phone: '1' * 31,
          shopName: 'x' * 201,
          shopAddress: 'x' * 201,
          email: '${'x' * 250}@ex.com',
        ),
        {
          AuthField.fullName: AuthFieldIssue.tooLong,
          AuthField.phone: AuthFieldIssue.tooLong,
          AuthField.shopName: AuthFieldIssue.tooLong,
          AuthField.shopAddress: AuthFieldIssue.tooLong,
          AuthField.email: AuthFieldIssue.tooLong,
        },
      );
    });
  });
}
