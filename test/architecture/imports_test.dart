import 'package:flutter_test/flutter_test.dart';

import 'source_files.dart';

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
        // start-up through the auth providers.
        final splashUsesAuth =
            own == 'splash' &&
            target.startsWith(
              'package:stockly/features/auth/presentation/providers/',
            );
        if (match != null && match.group(1) != own && !splashUsesAuth) {
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
