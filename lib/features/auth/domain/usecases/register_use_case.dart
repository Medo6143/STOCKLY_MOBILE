import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';

final class RegisterUseCase {
  const new(this._repository);

  final AuthRepository _repository;

  Future<Result<Session, Failure>> call(RegisterInput input) =>
      _repository.register(input);
}
