import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/features/auth/data/models/session_mapper.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/session_restoration.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';
import 'package:stockly/features/auth/domain/usecases/login_use_case.dart';
import 'package:stockly/features/auth/domain/usecases/logout_use_case.dart';
import 'package:stockly/features/auth/domain/usecases/register_use_case.dart';
import 'package:stockly/features/auth/domain/usecases/restore_session_use_case.dart';

import '../../../helpers/test_doubles.dart';

class _MockAuthRepository extends Mock implements AuthRepository;

final Session _session = storedSession().toEntity();

const RegisterInput _input = RegisterInput(
  fullName: 'Mona Adel',
  email: 'mona@example.com',
  password: 'Str0ngPass',
  preferredLanguage: AppLanguage.ar,
  shopName: 'صيدلية الشفاء',
  shopType: ShopType.pharmacy,
);

const ApiProblemInfo _info = ApiProblemInfo(status: 401);

void main() {
  late _MockAuthRepository repository;

  setUpAll(() => registerFallbackValue(_input));

  setUp(() => repository = _MockAuthRepository());

  group('RestoreSessionUseCase', () {
    late RestoreSessionUseCase useCase;

    setUp(() => useCase = RestoreSessionUseCase(repository));

    test('call_NoCachedSession_None', () async {
      when(() => repository.cachedSession()).thenAnswer((_) async => null);

      expect(await useCase(), const SessionRestoration.none());
      verifyNever(() => repository.restoreSession());
    });

    test('call_Confirmed_Active', () async {
      when(() => repository.cachedSession()).thenAnswer((_) async => _session);
      when(() => repository.restoreSession())
          .thenAnswer((_) async => Ok(_session));

      expect(await useCase(), SessionRestoration.active(_session));
    });

    test('call_Rejected_Ended', () async {
      const failure = SessionEndedFailure(
        ApiErrorCode.authRefreshTokenReused,
        _info,
      );
      when(() => repository.cachedSession()).thenAnswer((_) async => _session);
      when(() => repository.restoreSession())
          .thenAnswer((_) async => const Err(failure));

      expect(await useCase(), const SessionRestoration.ended(failure));
    });

    test('call_Suspended_SuspendedWithCachedSession', () async {
      when(() => repository.cachedSession()).thenAnswer((_) async => _session);
      when(() => repository.restoreSession()).thenAnswer(
        (_) async => const Err(
          ShopSuspendedFailure(
            ApiErrorCode.shopSuspended,
            ApiProblemInfo(status: 403),
          ),
        ),
      );

      expect(await useCase(), SessionRestoration.suspended(_session));
    });

    test('call_Unreachable_OfflineWithCachedSession', () async {
      when(() => repository.cachedSession()).thenAnswer((_) async => _session);
      for (final failure in <Failure>[
        const NetworkFailure(),
        const TimeoutFailure(),
        const ServerFailure(
          ApiErrorCode.serverUnexpected,
          ApiProblemInfo(status: 500),
        ),
      ]) {
        when(() => repository.restoreSession())
            .thenAnswer((_) async => Err(failure));

        expect(await useCase(), SessionRestoration.offline(_session));
      }
    });
  });

  group('LoginUseCase', () {
    test('call_TrimsEmail_PassesPasswordAsTyped', () async {
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Ok(_session));

      final result = await LoginUseCase(repository)(
        email: ' mona@stockly.test ',
        password: ' pass word ',
      );

      expect(result, isA<Ok<Session, Failure>>());
      verify(
        () => repository.login(
          email: 'mona@stockly.test',
          password: ' pass word ',
        ),
      ).called(1);
    });

    test('call_InvalidCredentials_ReturnsFailure', () async {
      const failure = InvalidCredentialsFailure(
        ApiErrorCode.authInvalidCredentials,
        _info,
      );
      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => const Err(failure));

      final result = await LoginUseCase(repository)(email: 'a', password: 'b');

      expect((result as Err<Session, Failure>).failure, failure);
    });
  });

  group('RegisterUseCase', () {
    test('call_DelegatesToRepository', () async {
      const failure = ConflictFailure(
        ApiErrorCode.authEmailTaken,
        ApiProblemInfo(status: 409),
      );
      when(() => repository.register(any()))
          .thenAnswer((_) async => const Err(failure));

      final result = await RegisterUseCase(repository)(_input);

      expect((result as Err<Session, Failure>).failure, failure);
      verify(() => repository.register(_input)).called(1);
    });
  });

  group('LogoutUseCase', () {
    test('call_DelegatesToRepository', () async {
      when(() => repository.logout()).thenAnswer((_) async {});

      await LogoutUseCase(repository)();

      verify(() => repository.logout()).called(1);
    });
  });
}
