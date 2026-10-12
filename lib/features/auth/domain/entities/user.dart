import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';

part 'user.freezed.dart';

@freezed
abstract class User with _$User {
  const factory({
    required String id,
    required String email,
    required String fullName,
    required String? phone,
    required AppLanguage preferredLanguage,
  }) = _User;
}
