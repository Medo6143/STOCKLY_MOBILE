import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/config/app_version.dart';

void main() {
  test('AppVersion_MatchesPubspec', () {
    final version = RegExp(
      r'^version:\s*(\S+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!;

    expect(AppVersion.name, version.group(1));
    expect(AppVersion.build, int.parse(version.group(2)!));
    expect(AppVersion.display, '${version.group(1)} (${version.group(2)})');
  });
}
