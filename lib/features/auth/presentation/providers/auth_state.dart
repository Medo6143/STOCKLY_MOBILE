import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';

part 'auth_state.freezed.dart';

/// Where the app stands with the user's session (design §1.4).
@freezed
sealed class AuthState with _$AuthState {
  /// The saved session has not been checked yet.
  const factory unknown() = AuthUnknown;

  /// No session. [reason] is set when the server ended it.
  const factory signedOut({Failure? reason}) = AuthSignedOut;

  /// Signed in. [offline] when the server could not confirm the session at
  /// start-up and the cached snapshot is used.
  const factory signedIn(Session session, {required bool offline}) =
      AuthSignedIn;

  /// The shop is suspended: only logout is possible.
  const factory suspended(Session session) = AuthSuspended;
}
