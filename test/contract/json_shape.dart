import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A JSON fixture copied from the contract (`test/fixtures/contract`).
Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/contract/$name.json').readAsStringSync())
        as Map<String, Object?>;

final RegExp _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final RegExp _timestamp = RegExp(
  r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$',
);

/// `*Id` fields that are not UUIDs.
const Set<String> _freeTextIds = {'correlationId', 'traceId', 'deviceId'};

/// Contract enum values by field name (contract §3).
const Map<String, Set<String>> _enums = {
  'shopType': {'Pharmacy', 'Grocery', 'MobileShop', 'Other'},
  'status': {'Active', 'Suspended'},
  'role': {'Owner', 'Staff'},
  'preferredLanguage': {'ar', 'en'},
};

/// Asserts that [actual] has exactly the fields of [expected], with the same
/// JSON types and the contract's formats (ids, timestamps, enum strings).
/// A `null` on either side matches a string (nullable field).
void expectSameShape(Object? actual, Object? expected, {String path = r'$'}) {
  if (expected is Map<String, Object?>) {
    expect(actual, isA<Map<String, Object?>>(), reason: path);
    final map = actual! as Map<String, Object?>;
    expect(map.keys.toSet(), expected.keys.toSet(), reason: path);
    for (final key in expected.keys) {
      _expectField(key, map[key], expected[key], '$path.$key');
    }
    return;
  }
  fail('Fixture root must be a JSON object at $path');
}

void _expectField(String key, Object? actual, Object? expected, String path) {
  if (expected is Map<String, Object?>) {
    expectSameShape(actual, expected, path: path);
    return;
  }
  if (actual == null || expected == null) {
    expect(
      actual == null || actual is String,
      isTrue,
      reason: '$path must be a string or null',
    );
    expect(
      expected == null || expected is String,
      isTrue,
      reason: '$path fixture must be a string or null',
    );
    return;
  }
  expect(actual.runtimeType, expected.runtimeType, reason: path);
  if (actual is! String) {
    return;
  }
  if (key == 'id' || key.endsWith('Id') && !_freeTextIds.contains(key)) {
    expect(actual, matches(_uuid), reason: '$path is a lower-case UUID');
  }
  if (key.endsWith('At')) {
    expect(actual, matches(_timestamp), reason: '$path is ISO-8601 UTC');
  }
  final values = _enums[key];
  if (values != null) {
    expect(values, contains(actual), reason: '$path is a contract enum');
  }
}
