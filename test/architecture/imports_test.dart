import 'package:flutter_test/flutter_test.dart';

import 'source_files.dart';

/// Features that use the app-wide session providers of the auth feature.
/// Products reads `isOwnerProvider` for the Owner-only actions (design
/// §2.3, §11); invoices scopes the scan queue and the capture to the
/// signed-in shop (design §2.3 `pendingScansProvider`, §6.7); sales scopes
/// the pending sales to the signed-in shop (design §6.8).
const Set<String> _sessionConsumers = {
  'splash',
  'settings',
  'products',
  'invoices',
  'sales',
};

const String _productsProviders =
    'package:stockly/features/products/presentation/providers/products_providers.dart';
const String _productList =
    'package:stockly/features/products/presentation/providers/product_list_notifier.dart';
const String _dashboardSummary =
    'package:stockly/features/dashboard/presentation/providers/dashboard_summary_notifier.dart';

/// The only other cross-feature provider files a feature may import, each
/// required by the design.
const Map<String, Set<String>> _sharedProviders = {
  // Design §2.3: the review's product picker and unit choice read the
  // catalogue through the products use-case providers.
  // Design §2.3: invoice confirm invalidates the product list and the
  // dashboard.
  'invoices': {_productsProviders, _productList, _dashboardSummary},
  // Design §2.3: the quick sale looks products up through the products
  // use-case providers (P12, P1, P2); a sale invalidates the product list
  // and the dashboard.
  'sales': {_productsProviders, _productList, _dashboardSummary},
  // Design §6.7: sign out warns about the shop's scans not uploaded yet.
  'settings': {
    'package:stockly/features/invoices/presentation/providers/pending_scans_providers.dart',
  },
};

/// Design §1.1 and §13.4.
void main() {
  final files = handWrittenLibFiles();

  test('LibHasHandWrittenFiles', () {
    expect(files, isNotEmpty);
  });

  test('Presentation_NeverImportsDioDriftDataOrNetwork', () {
    final violations = <String>[];
    for (final file in files) {
      final path = normalizedPath(file);
      if (!path.contains('/presentation/')) {
        continue;
      }
      final isCompositionRoot = RegExp(
        r'/presentation/providers/\w+_providers\.dart$',
      ).hasMatch(path);
      for (final target in importsOf(file.readAsStringSync())) {
        final banned =
            target.startsWith('package:dio/') ||
            target.startsWith('package:drift/') ||
            target.contains('/core/network/') ||
            target.contains('/data/');
        if (banned && !isCompositionRoot) {
          violations.add('$path -> $target');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('Domain_ImportsOnlyCoreErrorDecimalTimeAndDomain', () {
    final violations = <String>[];
    for (final file in files) {
      final path = normalizedPath(file);
      if (!path.contains('/domain/')) {
        continue;
      }
      for (final target in importsOf(file.readAsStringSync())) {
        final allowed =
            target.startsWith('dart:') ||
            target == 'package:freezed_annotation/freezed_annotation.dart' ||
            target.startsWith('package:stockly/core/error/') ||
            target.startsWith('package:stockly/core/decimal/') ||
            target.startsWith('package:stockly/core/time/') ||
            // Design §1.4: `Paged<T>` is shared by every list.
            target == 'package:stockly/core/pagination/paged.dart' ||
            RegExp(r'^package:stockly/features/\w+/domain/').hasMatch(target);
        if (!allowed) {
          violations.add('$path -> $target');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('Features_NeverImportAnotherFeaturesDataOrPresentation', () {
    final violations = <String>[];
    final featureOf = RegExp(r'features/(\w+)/');
    for (final file in files) {
      final path = normalizedPath(file);
      final own = featureOf.firstMatch(path)?.group(1);
      if (own == null) {
        continue;
      }
      for (final target in importsOf(file.readAsStringSync())) {
        final match = RegExp(
          r'^package:stockly/features/(\w+)/(data|presentation)/',
        ).firstMatch(target);
        // Design §1.4: the splash has no data or domain layer and drives
        // start-up through the auth providers. Design §2.2: the session
        // providers (`authProvider`, `currentSessionProvider`,
        // `isOwnerProvider`) are app-wide, so settings reads the session and
        // signs out through them, and products hides Owner-only actions.
        final usesSessionProviders =
            _sessionConsumers.contains(own) &&
            target.startsWith(
              'package:stockly/features/auth/presentation/providers/',
            );
        final usesSharedProviders =
            _sharedProviders[own]?.contains(target) ?? false;
        if (match != null &&
            match.group(1) != own &&
            !usesSessionProviders &&
            !usesSharedProviders) {
          violations.add('$path -> $target');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('ColorLiterals_OnlyInTokens', () {
    final violations = [
      for (final file in files)
        if (normalizedPath(file) != 'lib/core/theme/tokens.dart' &&
            file.readAsStringSync().contains('Color(0x'))
          normalizedPath(file),
    ];
    expect(violations, isEmpty);
  });

  test('NoDirectClockOrUnlinkedTodo', () {
    final violations = <String>[];
    for (final file in files) {
      final path = normalizedPath(file);
      final source = file.readAsStringSync();
      if (path != 'lib/core/time/clock.dart' &&
          source.contains('DateTime.now()')) {
        violations.add('$path uses DateTime.now()');
      }
      if (RegExp(r'TODO(?!\(https?://)').hasMatch(source)) {
        violations.add('$path has a TODO without an issue link');
      }
    }
    expect(violations, isEmpty);
  });
}
