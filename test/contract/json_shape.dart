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
  'reason': {
    'InvoiceReceipt',
    'Sale',
    'ManualAdjustment',
    'StockCount',
    'InvoiceReversal',
  },
};

/// Contract §6 enum values; `status` means an invoice status there, so
/// invoice shapes pass these to [expectSameShape].
const Map<String, Set<String>> invoiceEnums = {
  'status': {'Processing', 'NeedsReview', 'Confirmed', 'Failed'},
  'warnings': {
    'TotalMismatch',
    'ItemCapExceeded',
    'UnreadableLines',
    'DuplicateInvoiceNumber',
  },
};

/// Contract §7 sale warning codes; `code` means an error code elsewhere,
/// so sale shapes pass these to [expectSameShape].
const Map<String, Set<String>> saleEnums = {
  'code': {'Stock.NegativeBalance'},
};

/// Contract §12.1 enum values; `status` means a payment status there, so
/// billing shapes pass these to [expectSameShape].
const Map<String, Set<String>> billingEnums = {
  'status': {'Pending', 'Paid', 'Failed', 'Expired'},
  'method': {'Card', 'Wallet', 'Kiosk'},
  'currency': {'EGP'},
};

/// Object fields the contract allows to be `null` (I4 `newProduct`, B2
/// `pendingPayment`).
const Set<String> _nullableObjects = {'newProduct', 'pendingPayment'};

/// Contract §1.2 `date` fields.
const Set<String> _dateFields = {
  'invoiceDate',
  'expiryDate',
  'startsOn',
  'endsOn',
};
final RegExp _date = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Contract §1.2 decimal strings by field name: money 2, quantity 3,
/// factor 6 decimals, confidence 2.
final Map<String, RegExp> _decimals = {
  for (final key in [
    'sellPrice',
    'costPrice',
    'unitPrice',
    'lineTotal',
    'totalAmount',
    'computedTotal',
    'matchConfidence',
    'listUnitPrice',
    'total',
    'monthlyPrice',
    'amount',
  ])
    key: RegExp(r'^\d+\.\d{2}$'),
  for (final key in [
    'quantity',
    'lowStockThreshold',
    'quantityChange',
    'balanceAfter',
    'countedQuantity',
    'openingQuantity',
    'lineQuantity',
    'currentQuantity',
  ])
    key: RegExp(r'^-?\d+\.\d{3}$'),
  'factor': RegExp(r'^\d+\.\d{6}$'),
};

/// Asserts that [actual] has exactly the fields of [expected], with the same
/// JSON types and the contract's formats (ids, timestamps, enum strings).
/// A `null` on either side matches a string (nullable field). [enums]
/// replaces the default enum values of a field name.
void expectSameShape(
  Object? actual,
  Object? expected, {
  String path = r'$',
  Map<String, Set<String>> enums = const {},
}) {
  if (expected is Map<String, Object?>) {
    expect(actual, isA<Map<String, Object?>>(), reason: path);
    final map = actual! as Map<String, Object?>;
    expect(map.keys.toSet(), expected.keys.toSet(), reason: path);
    for (final key in expected.keys) {
      _expectField(key, map[key], expected[key], '$path.$key', enums);
    }
    return;
  }
  fail('Fixture root must be a JSON object at $path');
}

void _expectField(
  String key,
  Object? actual,
  Object? expected,
  String path,
  Map<String, Set<String>> enums,
) {
  if (expected is Map<String, Object?>) {
    if (actual == null && _nullableObjects.contains(key)) {
      return;
    }
    expectSameShape(actual, expected, path: path, enums: enums);
    return;
  }
  if (expected is List<Object?>) {
    expect(actual, isA<List<Object?>>(), reason: path);
    final items = actual! as List<Object?>;
    if (expected.isNotEmpty) {
      for (var i = 0; i < items.length; i++) {
        _expectField(key, items[i], expected.first, '$path[$i]', enums);
      }
    }
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
  final decimal = _decimals[key];
  if (decimal != null) {
    expect(actual, matches(decimal), reason: '$path has the contract scale');
  }
  if (_dateFields.contains(key)) {
    expect(actual, matches(_date), reason: '$path is yyyy-MM-dd');
  }
  final values = enums[key] ?? _enums[key];
  if (values != null) {
    expect(values, contains(actual), reason: '$path is a contract enum');
  }
}
