import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Generates RFC 4122 ids (lower-case, hyphenated), above all the
/// `clientRequestId` that makes retries safe.
abstract interface class UuidGenerator {
  /// A random (version 4) UUID.
  String v4();
}

final class PackageUuidGenerator implements UuidGenerator {
  const new();

  static const Uuid _uuid = Uuid();

  @override
  String v4() => _uuid.v4();
}

final uuidGeneratorProvider = Provider<UuidGenerator>(
  (ref) => const PackageUuidGenerator(),
);
