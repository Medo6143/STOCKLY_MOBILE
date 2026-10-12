import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';

import '../../helpers/test_doubles.dart';

void main() {
  late Map<String, String> values;
  late MockFlutterSecureStorage secure;
  late CountingUuidGenerator uuid;
  late SecureTokenStorage storage;

  setUp(() {
    values = {};
    secure = secureStorageBackedBy(values);
    uuid = CountingUuidGenerator();
    storage = SecureTokenStorage(secure, uuid);
  });

  test('save_WritesOneJsonBlob_AndReadRoundTrips', () async {
    final session = storedSession();

    await storage.save(session);

    expect(values.keys, [SecureStorageKeys.session]);
    final json = jsonDecode(values[SecureStorageKeys.session]!) as Map;
    expect(json['accessToken'], 'access-1');
    expect(json['refreshToken'], 'refresh-1');
    expect(json['accessTokenExpiresAt'], '2026-10-12T07:15:00.000Z');
    expect(await storage.read(), session);
    expect(await SecureTokenStorage(secure, uuid).read(), session);
  });

  test('read_UsesCacheAfterFirstLoad', () async {
    await storage.save(storedSession());
    await storage.read();
    await storage.read();

    verifyNever(() => secure.read(key: SecureStorageKeys.session));
  });

  test('read_FirstTime_LoadsOnce', () async {
    values[SecureStorageKeys.session] = jsonEncode(storedSession().toJson());

    expect(await storage.read(), storedSession());
    expect(await storage.read(), storedSession());

    verify(() => secure.read(key: SecureStorageKeys.session)).called(1);
  });

  test('reload_SeesAnotherIsolatesWrite', () async {
    await storage.save(storedSession());
    values[SecureStorageKeys.session] = jsonEncode(
      storedSession(accessToken: 'access-2').toJson(),
    );

    expect((await storage.read())?.accessToken, 'access-1');
    expect((await storage.reload())?.accessToken, 'access-2');
  });

  test('clear_RemovesTheBlob', () async {
    await storage.save(storedSession());

    await storage.clear();

    expect(values, isEmpty);
    expect(await storage.read(), isNull);
  });

  test('read_CorruptBlob_IsNoSession', () async {
    values[SecureStorageKeys.session] = 'not json';
    expect(await storage.read(), isNull);

    values[SecureStorageKeys.session] = '{"accessToken": 1}';
    expect(await storage.reload(), isNull);

    values[SecureStorageKeys.session] = '[1, 2]';
    expect(await storage.reload(), isNull);
  });

  test('installationId_CreatedOnceThenReused', () async {
    final first = await storage.installationId();
    final second = await storage.installationId();
    final otherInstance = await SecureTokenStorage(
      secure,
      uuid,
    ).installationId();

    expect(first, second);
    expect(first, otherInstance);
    expect(uuid.count, 1);
    expect(values[SecureStorageKeys.installationId], first);
  });
}
