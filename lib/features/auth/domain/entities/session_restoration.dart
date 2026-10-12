import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';

part 'session_restoration.freezed.dart';

/// What restoring the saved session at start-up found (design §3.2).
@freezed
sealed class SessionRestoration with _$SessionRestoration {
  /// No stored session: sign in.
  const factory none() = RestorationNone;

  /// `GET /api/auth/me` confirmed the session.
  const factory active(Session session) = RestorationActive;

  /// The server could not be reached: the cached snapshot is used.
  const factory offline(Session session) = RestorationOffline;

  /// The server rejected the session.
  const factory ended(SessionEndedFailure reason) = RestorationEnded;

  /// The shop is suspended.
  const factory suspended(Session session) = RestorationSuspended;
}
