import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';

part 'register_input.freezed.dart';

/// What the register form collects (contract A1). The device id is added by
/// the data layer.
@freezed
abstract class RegisterInput with _$RegisterInput {
  const factory({
    required String fullName,
    required String email,
    required String password,
    required AppLanguage preferredLanguage,
    required String shopName,
    required ShopType shopType,
    String? phone,
    String? shopPhone,
    String? shopGovernorate,
    String? shopAddress,
  }) = _RegisterInput;
}
