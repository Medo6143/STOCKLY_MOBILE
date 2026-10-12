import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';

/// The session cached on the device, without calling the server: the
/// offline start when the splash maximum passes before the server answers
/// (design §10.2).
final class GetCachedSessionUseCase {
  const new(this._repository);

  final AuthRepository _repository;

  Future<Session?> call() => _repository.cachedSession();
}
