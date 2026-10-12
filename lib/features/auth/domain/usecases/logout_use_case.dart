import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';

final class LogoutUseCase {
  const new(this._repository);

  final AuthRepository _repository;

  /// Always ends the local session, even offline (design §4.3).
  Future<void> call() => _repository.logout();
}
