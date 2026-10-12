import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/logging/app_logger.dart';
import 'package:stockly/core/platform/native_splash.dart';
import 'package:stockly/core/preferences/locale_notifier.dart';
import 'package:stockly/core/storage/preferences_store.dart';
import 'package:stockly/core/time/clock.dart';
import 'package:stockly/features/auth/data/models/session_mapper.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';

import 'test_doubles.dart';

class MockAuthRepository extends Mock implements AuthRepository;

/// Counts how often the native splash was removed.
final class FakeNativeSplash implements NativeSplash {
  int removed = 0;

  @override
  void remove() => removed++;
}

final Session ownerSession = storedSession().toEntity();
final Session staffSession = storedSession(role: 'Staff').toEntity();

ApiProblemInfo problemInfo(int status) =>
    ApiProblemInfo(status: status, traceId: '00-trace-00');

const InvalidCredentialsFailure invalidCredentials = InvalidCredentialsFailure(
  ApiErrorCode.authInvalidCredentials,
  ApiProblemInfo(status: 401),
);

const SessionEndedFailure sessionEnded = SessionEndedFailure(
  ApiErrorCode.authRefreshTokenReused,
  ApiProblemInfo(status: 401),
);

AccountLockedFailure lockedOut(Duration retryAfter) => AccountLockedFailure(
  ApiErrorCode.authLockedOut,
  const ApiProblemInfo(status: 423),
  retryAfter: retryAfter,
);

AuthRateLimitedFailure rateLimited(Duration retryAfter) =>
    AuthRateLimitedFailure(
      ApiErrorCode.authTooManyRequests,
      const ApiProblemInfo(status: 429),
      retryAfter: retryAfter,
    );

/// Registers mocktail fallbacks once per test file.
void registerAuthFallbacks() {
  registerFallbackValue(
    RegisterInput(
      fullName: 'x',
      email: 'x@x.x',
      password: 'x',
      preferredLanguage: ownerSession.user.preferredLanguage,
      shopName: 'x',
      shopType: ownerSession.shop.shopType,
    ),
  );
}

/// Overrides for a screen or notifier test over [repository]: no platform
/// channels, no database file.
List<Override> authTestOverrides({
  required AuthRepository repository,
  Clock? clock,
  PreferencesStore? preferences,
  Locale deviceLocale = const Locale('ar'),
}) => [
  authRepositoryProvider.overrideWithValue(repository),
  preferencesStoreProvider.overrideWithValue(
    preferences ?? InMemoryPreferencesStore(),
  ),
  deviceLocaleProvider.overrideWithValue(deviceLocale),
  appLoggerProvider.overrideWithValue(const NoopLogger()),
  if (clock != null) clockProvider.overrideWithValue(clock),
];
