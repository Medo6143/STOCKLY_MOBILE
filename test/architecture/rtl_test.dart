import 'package:flutter_test/flutter_test.dart';

import 'source_files.dart';

/// Rule 36 and design §8.5: no left/right APIs and no forced RTL.
final List<RegExp> _banned = [
  RegExp(r'EdgeInsets\.only\([^)]*\b(left|right):'),
  RegExp(r'EdgeInsets\.fromLTRB'),
  RegExp(
    r'\bAlignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)',
  ),
  RegExp(r'TextAlign\.(left|right)\b'),
  RegExp(r'\bPositioned\([^)]*\b(left|right):'),
  RegExp(
    r'BorderRadius\.only\([^)]*\b(topLeft|topRight|bottomLeft|bottomRight):',
  ),
  RegExp(r'TextDirection\.rtl'),
  RegExp(r'CrossAxisAlignment\.(left|right)'),
];

void main() {
  test('Lib_UsesOnlyDirectionalLayoutApis', () {
    final violations = <String>[];
    for (final file in handWrittenLibFiles()) {
      final source = file.readAsStringSync();
      for (final pattern in _banned) {
        for (final match in pattern.allMatches(source)) {
          violations.add('${normalizedPath(file)}: ${match.group(0)}');
        }
      }
    }
    expect(violations, isEmpty);
  });

  test('Patterns_CatchTheBannedApis', () {
    const samples = [
      'EdgeInsets.only(left: 8)',
      'EdgeInsets.fromLTRB(1, 2, 3, 4)',
      'Alignment.centerLeft',
      'TextAlign.right',
      'Positioned(right: 0, child: x)',
      'BorderRadius.only(topLeft: r)',
      'TextDirection.rtl',
    ];
    for (final sample in samples) {
      expect(_banned.any((p) => p.hasMatch(sample)), isTrue, reason: sample);
    }
    expect(
      _banned.any((p) => p.hasMatch('EdgeInsetsDirectional.only(start: 8)')),
      isFalse,
    );
  });
}
