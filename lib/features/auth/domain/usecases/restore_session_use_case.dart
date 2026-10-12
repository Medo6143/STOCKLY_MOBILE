import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/domain/entities/session_restoration.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';

/// Decides how the app starts (design §3.2): no stored session → sign in;
/// confirmed → signed in; rejected → signed out; suspended → suspended
/// screen; server unreachable → signed in offline with the cached snapshot.
final class RestoreSessionUseCase {
  const new(this._repository);

  final AuthRepository _repository;

  Future<SessionRestoration> call() async {
    final cached = await _repository.cachedSession();
    if (cached == null) {
      return const SessionRestoration.none();
    }
    return switch (await _repository.restoreSession()) {
      Ok(:final value) => SessionRestoration.active(value),
      Err(:final SessionEndedFailure failure) => SessionRestoration.ended(
        failure,
      ),
      Err(failure: ShopSuspendedFailure()) => SessionRestoration.suspended(
        cached,
      ),
      Err() => SessionRestoration.offline(cached),
    };
  }
}
