import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';

abstract interface class AuthRepository {
  /// A1: creates the user, shop and Owner membership and stores the session.
  Future<Result<Session, Failure>> register(RegisterInput input);

  /// A2: signs in and stores the session.
  Future<Result<Session, Failure>> login({
    required String email,
    required String password,
  });

  /// A5: confirms the stored session with the server and refreshes the
  /// cached user and shop.
  Future<Result<Session, Failure>> restoreSession();

  /// The session cached on the device, without calling the server.
  Future<Session?> cachedSession();

  /// A4, then clears the stored session whatever the server answered.
  Future<void> logout();
}
