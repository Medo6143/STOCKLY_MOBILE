import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/error/api_error_code.dart';
import 'package:stockly/core/error/failure.dart';
import 'package:stockly/core/error/result.dart';
import 'package:stockly/core/network/api_paths.dart';
import 'package:stockly/core/network/dio_client.dart';
import 'package:stockly/core/network/request_extras.dart';
import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:stockly/features/auth/data/models/session_mapper.dart';
import 'package:stockly/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:stockly/features/auth/domain/entities/app_language.dart';
import 'package:stockly/features/auth/domain/entities/register_input.dart';
import 'package:stockly/features/auth/domain/entities/session.dart';
import 'package:stockly/features/auth/domain/entities/shop_role.dart';
import 'package:stockly/features/auth/domain/entities/shop_status.dart';
import 'package:stockly/features/auth/domain/entities/shop_type.dart';
import 'package:stockly/features/auth/presentation/providers/auth_providers.dart';

import '../../../contract/json_shape.dart';
import '../../../helpers/scripted_adapter.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_doubles.dart';
import '../../../helpers/test_server.dart';

const RegisterInput _input = RegisterInput(
  fullName: 'Mona Adel',
  email: 'new@stockly.test',
  password: 'Str0ngPass',
  preferredLanguage: AppLanguage.en,
  shopName: 'Hope Grocery',
  shopType: ShopType.grocery,
  phone: '01001234567',
  shopGovernorate: 'Cairo',
);

void main() {
  late FakeClock clock;
  late TestServer server;
  late ScriptedAdapter adapter;
  late InMemoryTokenStorage tokens;
  late ProviderContainer container;
  late AuthRepositoryImpl repository;

  setUp(() {
    clock = FakeClock();
    server = TestServer();
    adapter = server.adapter;
    tokens = InMemoryTokenStorage();
    container = ProviderContainer.test(
      overrides: appOverrides(adapter: adapter, tokens: tokens, clock: clock),
    );
    repository = AuthRepositoryImpl(
      AuthRemoteDataSource(container.read(dioProvider)),
      tokens,
    );
  });

  test('register_Success_StoresSessionAndSendsContractBody', () async {
    final result = await repository.register(_input);

    final session = (result as Ok<Session, Failure>).value;
    expect(session.shop.role, ShopRole.owner);
    expect(session.shop.shopType, ShopType.grocery);
    expect(session.user.preferredLanguage, AppLanguage.en);
    expect(tokens.session, isNotNull);
    final sent = adapter.requests.single.data as Map<String, dynamic>;
    expectSameShape(sent, fixture('register_request'));
    expect(sent['deviceId'], 'installation-id-for-tests');
    expect((sent['shop'] as Map)['shopType'], 'Grocery');
  });

  test('register_EmailTaken_ConflictAndNothingStored', () async {
    final result = await repository.register(
      _input.copyWith(email: TestServer.ownerEmail),
    );

    final failure = (result as Err<Session, Failure>).failure;
    expect(failure, isA<ConflictFailure>());
    expect((failure as ConflictFailure).code, ApiErrorCode.authEmailTaken);
    expect(tokens.session, isNull);
  });

  test('login_Success_StoresSessionWithSnapshot', () async {
    final result = await repository.login(
      email: TestServer.ownerEmail,
      password: TestServer.password,
    );

    final session = (result as Ok<Session, Failure>).value;
    expect(session.shop.status, ShopStatus.active);
    expect(tokens.session?.user.email, TestServer.ownerEmail);
    expect(await repository.cachedSession(), session);
    expect(adapter.requests.single.headers['Authorization'], isNull);
  });

  test('login_WrongPassword_InvalidCredentials', () async {
    final result = await repository.login(
      email: TestServer.ownerEmail,
      password: 'Wrong1234',
    );

    expect(
      (result as Err<Session, Failure>).failure,
      isA<InvalidCredentialsFailure>(),
    );
  });

  test('restoreSession_UpdatesSnapshotFromMe', () async {
    tokens.session = await signIn(adapter);
    tokens.session = tokens.session!.copyWith(
      user: tokens.session!.user.copyWith(fullName: 'Old name'),
    );

    final result = await repository.restoreSession();

    // The name of the `me_response` contract fixture.
    expect((result as Ok<Session, Failure>).value.user.fullName, 'Mona Adel');
    expect(tokens.session?.user.fullName, 'Mona Adel');
  });

  test('restoreSession_ExpiredAccessToken_RefreshesThenSucceeds', () async {
    tokens.session = await signIn(adapter);
    final oldRefresh = tokens.session!.refreshToken;
    server.expireAccessTokens();
    adapter.requests.clear();

    final result = await repository.restoreSession();

    expect(result, isA<Ok<Session, Failure>>());
    expect(tokens.session?.refreshToken, isNot(oldRefresh));
    expect(adapter.requests.map((r) => r.path), [
      ApiPaths.authMe,
      ApiPaths.authRefresh,
      ApiPaths.authMe,
    ]);
  });

  test('restoreSession_SuspendedShop_ShopSuspendedFailure', () async {
    tokens.session = await signIn(adapter);
    server.suspended = true;

    final result = await repository.restoreSession();

    expect(
      (result as Err<Session, Failure>).failure,
      isA<ShopSuspendedFailure>(),
    );
    expect(tokens.session, isNotNull);
  });

  test('restoreSession_SessionGoneDuringCall_SessionEnded', () async {
    final scripted = ScriptedAdapter(
      (_) async => jsonBody(200, {
        'user': authResponseJson(accessToken: 'a', refreshToken: 'r')['user'],
        'shop': authResponseJson(accessToken: 'a', refreshToken: 'r')['shop'],
      }),
    );
    final dio = buildBaseDio(config: testConfig, adapter: scripted);
    final repo = AuthRepositoryImpl(AuthRemoteDataSource(dio), tokens);

    final result = await repo.restoreSession();

    expect(
      (result as Err<Session, Failure>).failure,
      isA<SessionEndedFailure>(),
    );
  });

  test('restoreSession_MalformedBody_MalformedResponseFailure', () async {
    final scripted = ScriptedAdapter(
      (_) async => jsonBody(200, {
        'user': {'id': 1},
      }),
    );
    final repo = AuthRepositoryImpl(
      AuthRemoteDataSource(buildBaseDio(config: testConfig, adapter: scripted)),
      tokens,
    );

    final result = await repo.restoreSession();

    expect(
      (result as Err<Session, Failure>).failure,
      isA<MalformedResponseFailure>(),
    );
  });

  test('login_UnknownEnumInResponse_MalformedAndNothingStored', () async {
    final json = authResponseJson(accessToken: 'a', refreshToken: 'r');
    (json['shop']! as Map<String, Object?>)['shopType'] = 'Bakery';
    final repo = AuthRepositoryImpl(
      AuthRemoteDataSource(
        buildBaseDio(
          config: testConfig,
          adapter: ScriptedAdapter((_) async => jsonBody(200, json)),
        ),
      ),
      tokens,
    );

    final result = await repo.login(email: 'a', password: 'b');

    expect(
      (result as Err<Session, Failure>).failure,
      isA<MalformedResponseFailure>(),
    );
    expect(tokens.session, isNull);
  });

  test('cachedSession_UnreadableSnapshot_IsNull', () async {
    tokens.session = storedSession().copyWith(
      shop: const ShopMembershipDto(
        id: 'x',
        name: 'x',
        shopType: 'Unknown',
        status: 'Active',
        role: 'Owner',
      ),
    );

    expect(await repository.cachedSession(), isNull);
  });

  test('logout_CallsServerAndClearsLocally', () async {
    tokens.session = await signIn(adapter);
    final refresh = tokens.session!.refreshToken;
    adapter.requests.clear();

    await repository.logout();

    expect(tokens.session, isNull);
    // The revoke runs in the background, after the local clear.
    await pumpEventQueue();
    final call = adapter.requests.single;
    expect(call.path, ApiPaths.authLogout);
    expect(call.data, {'refreshToken': refresh});
    expect(server.revokedRefreshTokens, contains(refresh));
  });

  test('logout_ServerUnreachable_StillClearsLocally', () async {
    tokens.session = storedSession();
    final offline = AuthRepositoryImpl(
      AuthRemoteDataSource(
        buildBaseDio(
          config: testConfig,
          adapter: ScriptedAdapter(
            (options) async => throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
          ),
        ),
      ),
      tokens,
    );

    await offline.logout();

    expect(tokens.session, isNull);
  });

  test('logout_ClearsWithoutWaitingForTheServer', () async {
    tokens.session = storedSession();
    final server = Completer<ResponseBody>();
    final adapter = ScriptedAdapter((_) => server.future);
    final slow = AuthRepositoryImpl(
      AuthRemoteDataSource(buildBaseDio(config: testConfig, adapter: adapter)),
      tokens,
    );

    // The server never answers here: signing out must not wait for it.
    await slow.logout();

    expect(tokens.session, isNull);
    await pumpEventQueue();
    final call = adapter.requests.single;
    expect(call.path, ApiPaths.authLogout);
    expect(call.data, {'refreshToken': 'refresh-1'});
    // The tokens are gone already, so the call carries its own.
    expect(
      call.headers[HttpHeaderNames.authorization],
      '${HttpHeaderNames.bearerPrefix}access-1',
    );
    expect(call.extra[RequestExtras.anonymous], isTrue);
    server.complete(jsonBody(204, null));
  });

  test('logout_NoSession_OnlyClears', () async {
    await repository.logout();

    expect(adapter.requests, isEmpty);
    expect(tokens.clearCount, 1);
  });

  test('providers_BuildTheRepositoryFromTheContainer', () {
    expect(container.read(authRepositoryProvider), isA<AuthRepositoryImpl>());
    expect(storedSession().toEntity().shop.role, ShopRole.owner);
  });
}
