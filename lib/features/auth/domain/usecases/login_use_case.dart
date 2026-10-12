import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';

final class LoginUseCase {
  const new(this._repository);

  final AuthRepository _repository;

  /// The email is sent trimmed; the password exactly as typed.
  Future<Result<Session, Failure>> call({
    required String email,
    required String password,
  }) => _repository.login(email: email.trim(), password: password);
}
