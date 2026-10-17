import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/presentation/providers/auth_notifier.dart';

/// The session shown on the profile, from memory (no request): data when
/// signed in, an error when the session could not be read, else loading.
final profileSessionProvider = Provider<AsyncValue<Session>>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session != null) {
    return AsyncData(session);
  }
  final auth = ref.watch(authProvider);
  if (auth case AsyncError(:final error, :final stackTrace)) {
    return AsyncError(error, stackTrace);
  }
  return const AsyncLoading();
});
