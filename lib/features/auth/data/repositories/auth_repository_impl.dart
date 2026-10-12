import 'dart:io';

import 'package:stockly/core/config/network_timeouts.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/safe_api_call.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/storage/stored_session.dart';
import 'package:stockly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stockly/features/auth/data/models/login_request_dto.dart';
import 'package:stockly/features/auth/data/models/logout_request_dto.dart';
import 'package:stockly/features/auth/data/models/me_response_dto.dart';
import 'package:stockly/features/auth/data/models/register_request_dto.dart';
import 'package:stockly/features/auth/data/models/session_mapper.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/repositories/auth_repository.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const new(this._remote, this._tokens);

  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  /// Used when the stored session disappears while `me` is running (the
  /// session ended in the meantime).
  static const SessionEndedFailure _sessionGone = SessionEndedFailure(
    ApiErrorCode.authUnauthenticated,
    ApiProblemInfo(status: HttpStatus.unauthorized),
  );

  @override
  Future<Result<Session, Failure>> register(RegisterInput input) =>
      safeApiCall(() async {
        final response = await _remote.register(
          RegisterRequestDto(
            fullName: input.fullName,
            email: input.email,
            password: input.password,
            phone: input.phone,
            preferredLanguage: input.preferredLanguage.name,
            deviceId: await _tokens.installationId(),
            shop: RegisterShopDto(
              name: input.shopName,
              shopType: AuthWire.shopTypes[input.shopType]!,
              phone: input.shopPhone,
              governorate: input.shopGovernorate,
              address: input.shopAddress,
            ),
          ),
        );
        return await _store(StoredSession.fromAuthResponse(response));
      });

  @override
  Future<Result<Session, Failure>> login({
    required String email,
    required String password,
  }) => safeApiCall(() async {
    final response = await _remote.login(
      LoginRequestDto(
        email: email,
        password: password,
        deviceId: await _tokens.installationId(),
      ),
    );
    return await _store(StoredSession.fromAuthResponse(response));
  });

  @override
  Future<Result<Session, Failure>> restoreSession() async {
    final me = await safeApiCall<MeResponseDto>(
      () => _remote.me(timeout: NetworkTimeouts.meStartup),
    );
    switch (me) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final stored = await _tokens.read();
        if (stored == null) {
          return const Err(_sessionGone);
        }
        return await safeApiCall(
          () => _store(stored.copyWith(user: value.user, shop: value.shop)),
        );
    }
  }

  @override
  Future<Session?> cachedSession() async {
    final stored = await _tokens.read();
    try {
      return stored?.toEntity();
    } on FormatException {
      // A snapshot written by an older app version: sign in again.
      return null;
    }
  }

  @override
  Future<void> logout() async {
    final stored = await _tokens.read();
    if (stored != null) {
      await safeApiCall(
        () =>
            _remote.logout(LogoutRequestDto(refreshToken: stored.refreshToken)),
      );
    }
    await _tokens.clear();
  }

  /// Maps first, so a snapshot that breaks the contract is never stored.
  Future<Session> _store(StoredSession session) async {
    final entity = session.toEntity();
    await _tokens.save(session);
    return entity;
  }
}
