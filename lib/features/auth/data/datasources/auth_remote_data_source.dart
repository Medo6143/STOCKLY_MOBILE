import 'package:dio/dio.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/json_body.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/features/auth/data/models/login_request_dto.dart';
import 'package:stockly/features/auth/data/models/logout_request_dto.dart';
import 'package:stockly/features/auth/data/models/me_response_dto.dart';
import 'package:stockly/features/auth/data/models/register_request_dto.dart';

/// A1, A2, A4 and A5. Refresh (A3) lives in `TokenRefresher` because the
/// interceptors need it. Throws `DioException`; the repository maps it.
final class AuthRemoteDataSource {
  const new(this._dio);

  final Dio _dio;

  Options get _anonymous => Options(extra: {RequestExtras.anonymous: true});

  Future<AuthResponseDto> register(RegisterRequestDto request) async {
    final response = await _dio.post<Object?>(
      ApiPaths.authRegister,
      data: request.toJson(),
      options: _anonymous,
    );
    return AuthResponseDto.fromJson(requireJsonObject(response.data));
  }

  Future<AuthResponseDto> login(LoginRequestDto request) async {
    final response = await _dio.post<Object?>(
      ApiPaths.authLogin,
      data: request.toJson(),
      options: _anonymous,
    );
    return AuthResponseDto.fromJson(requireJsonObject(response.data));
  }

  /// A4 with the [accessToken] of the session being ended. The local tokens
  /// are cleared before this call, so it carries its own and is not
  /// refreshed on `401` (best effort: the refresh token also expires).
  Future<void> logout(
    LogoutRequestDto request, {
    required String accessToken,
  }) => _dio.post<Object?>(
    ApiPaths.authLogout,
    data: request.toJson(),
    options: Options(
      headers: {
        HttpHeaderNames.authorization:
            '${HttpHeaderNames.bearerPrefix}$accessToken',
      },
      extra: {RequestExtras.anonymous: true},
    ),
  );

  /// [timeout] bounds the call at start-up (`NetworkTimeouts.meStartup`).
  Future<MeResponseDto> me({Duration? timeout}) async {
    final response = await _dio.get<Object?>(
      ApiPaths.authMe,
      options: Options(
        connectTimeout: timeout,
        sendTimeout: timeout,
        receiveTimeout: timeout,
      ),
    );
    return MeResponseDto.fromJson(requireJsonObject(response.data));
  }
}
