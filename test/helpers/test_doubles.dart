import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/offline/lease.dart';
import 'package:stockly/core/session/session_dtos.dart';
import 'package:stockly/core/storage/preferences_store.dart';
import 'package:stockly/core/storage/secure_token_storage.dart';
import 'package:stockly/core/storage/stored_session.dart';
import 'package:stockly/core/time/clock.dart';

/// A clock that only moves when the test moves it.
final class FakeClock implements Clock {
  new([DateTime? start]) : _now = start ?? DateTime.utc(2026, 10, 12, 7);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration by) => _now = _now.add(by);
}

/// Real v4 UUIDs, counted so tests can assert how many were generated.
final class CountingUuidGenerator implements UuidGenerator {
  int count = 0;

  @override
  String v4() {
    count++;
    return const PackageUuidGenerator().v4();
  }
}

/// A [TokenStorage] in memory. [reloadSession] simulates another isolate
/// writing secure storage.
final class InMemoryTokenStorage implements TokenStorage {
  new([this.session]);

  StoredSession? session;

  /// What `reload()` returns when set (another isolate's write).
  StoredSession? reloadSession;
  int clearCount = 0;
  int saveCount = 0;

  @override
  Future<StoredSession?> read() async => session;

  @override
  Future<StoredSession?> reload() async {
    if (reloadSession != null) {
      session = reloadSession;
      reloadSession = null;
    }
    return session;
  }

  @override
  Future<void> save(StoredSession value) async {
    saveCount++;
    session = value;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    session = null;
  }

  @override
  Future<String> installationId() async => 'installation-id-for-tests';
}

/// Runs every action at once, like a free lease.
final class ImmediateLeaseService implements LeaseService {
  int calls = 0;

  @override
  Future<T?> withLease<T>(
    String name, {
    required Duration ttl,
    required Duration wait,
    required Future<T> Function() action,
  }) {
    calls++;
    return action();
  }
}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage;

/// A [MockFlutterSecureStorage] backed by [values].
MockFlutterSecureStorage secureStorageBackedBy(Map<String, String> values) {
  final storage = MockFlutterSecureStorage();
  when(() => storage.read(key: any(named: 'key')))
      .thenAnswer((i) async => values[i.namedArguments[#key] as String]);
  when(
    () => storage.write(
      key: any(named: 'key'),
      value: any(named: 'value'),
    ),
  ).thenAnswer((i) async {
    final key = i.namedArguments[#key] as String;
    final value = i.namedArguments[#value] as String?;
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  });
  when(() => storage.delete(key: any(named: 'key')))
      .thenAnswer((i) async => values.remove(i.namedArguments[#key] as String));
  return storage;
}

/// A stored session with fixed values.
StoredSession storedSession({
  String accessToken = 'access-1',
  String refreshToken = 'refresh-1',
  String role = 'Owner',
  String status = 'Active',
}) => StoredSession(
  accessToken: accessToken,
  accessTokenExpiresAt: DateTime.utc(2026, 10, 12, 7, 15),
  refreshToken: refreshToken,
  refreshTokenExpiresAt: DateTime.utc(2026, 11, 11, 7),
  user: const UserDto(
    id: '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d02',
    email: 'mona@stockly.test',
    fullName: 'منى عادل',
    phone: null,
    preferredLanguage: 'ar',
  ),
  shop: ShopMembershipDto(
    id: '0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d01',
    name: 'صيدلية الشفاء',
    shopType: 'Pharmacy',
    status: status,
    role: role,
  ),
);

/// A [PreferencesStore] in memory.
final class InMemoryPreferencesStore implements PreferencesStore {
  final Map<PreferenceKey, String> values = {};

  @override
  Future<String?> read(PreferenceKey key) async => values[key];

  @override
  Future<void> write(PreferenceKey key, String value) async =>
      values[key] = value;
}
