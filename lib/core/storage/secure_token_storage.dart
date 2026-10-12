import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:stockly/core/ids/uuid_generator.dart';
import 'package:stockly/core/storage/stored_session.dart';

/// Keys in `flutter_secure_storage` (rule 38: tokens live only there).
abstract final class SecureStorageKeys {
  /// One JSON blob, so tokens and expiries are written atomically.
  static const String session = 'stockly.session';

  /// Random id created on first run, sent as `deviceId`.
  static const String installationId = 'stockly.installation_id';
}

/// Access to the stored session (design §4.3).
abstract interface class TokenStorage {
  /// The session, from the in-memory cache once loaded.
  Future<StoredSession?> read();

  /// Reads secure storage again, ignoring the cache. Used by the refresher to
  /// see a refresh made by another isolate.
  Future<StoredSession?> reload();

  Future<void> save(StoredSession session);

  Future<void> clear();

  /// The installation id, created once on first use.
  Future<String> installationId();
}

final class SecureTokenStorage implements TokenStorage {
  new(this._storage, this._uuid);

  final FlutterSecureStorage _storage;
  final UuidGenerator _uuid;

  bool _loaded = false;
  StoredSession? _cached;

  @override
  Future<StoredSession?> read() async {
    if (_loaded) {
      return _cached;
    }
    return await reload();
  }

  @override
  Future<StoredSession?> reload() async {
    final raw = await _storage.read(key: SecureStorageKeys.session);
    _cached = raw == null ? null : _decode(raw);
    _loaded = true;
    return _cached;
  }

  @override
  Future<void> save(StoredSession session) async {
    await _storage.write(
      key: SecureStorageKeys.session,
      value: jsonEncode(session.toJson()),
    );
    _cached = session;
    _loaded = true;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: SecureStorageKeys.session);
    _cached = null;
    _loaded = true;
  }

  @override
  Future<String> installationId() async {
    final existing = await _storage.read(key: SecureStorageKeys.installationId);
    if (existing != null) {
      return existing;
    }
    final created = _uuid.v4();
    await _storage.write(key: SecureStorageKeys.installationId, value: created);
    return created;
  }

  /// A blob that does not decode (for example after a format change) is
  /// treated as no session: the user signs in again.
  StoredSession? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? StoredSession.fromJson(json) : null;
    } on FormatException {
      return null;
    } on CheckedFromJsonException {
      return null;
    }
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => SecureTokenStorage(
    ref.watch(secureStorageProvider),
    ref.watch(uuidGeneratorProvider),
  ),
);
