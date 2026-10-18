import 'package:flutter_test/flutter_test.dart';

import '../../tool/coverage_gate.dart';

const String _lcov = r'''
SF:lib\features\sales\domain\usecases\create_sale.dart
DA:1,1
DA:2,0
DA:3,4
LF:3
LH:2
end_of_record
SF:lib/features/sales/presentation/providers/cart_notifier.dart
DA:10,1
DA:11,1
end_of_record
SF:lib/features/sales/presentation/providers/cart_state.freezed.dart
DA:1,0
DA:2,0
end_of_record
SF:lib/features/sales/presentation/screens/quick_sale_screen.dart
DA:1,0
end_of_record
SF:lib/core/decimal/money.dart
DA:1,0
end_of_record
''';

/// The CI coverage gate (brief mobile-6 §3.1).
void main() {
  test('normalizePath_BackslashesAndDotSlash', () {
    expect(
      normalizePath(r'lib\features\a\domain\b.dart'),
      'lib/features/a/domain/b.dart',
    );
    expect(normalizePath('./lib/a.dart'), 'lib/a.dart');
  });

  test('isGatedSource_DomainAndProvidersOnly', () {
    expect(isGatedSource('lib/features/a/domain/entities/b.dart'), isTrue);
    expect(
      isGatedSource('lib/features/a/presentation/providers/b.dart'),
      isTrue,
    );
    expect(
      isGatedSource('lib/features/a/presentation/screens/b.dart'),
      isFalse,
    );
    expect(isGatedSource('lib/features/a/data/b.dart'), isFalse);
    expect(isGatedSource('lib/core/decimal/money.dart'), isFalse);
    expect(isGatedSource('lib/features/a/domain/b.freezed.dart'), isFalse);
    expect(isGatedSource('lib/features/a/domain/b.g.dart'), isFalse);
  });

  test('parseLcov_CountsDaLines', () {
    final records = parseLcov(_lcov);

    final useCase =
        records['lib/features/sales/domain/usecases/create_sale.dart']!;
    expect(useCase.found, 3);
    expect(useCase.hit, 2);
    expect(records, hasLength(5));
  });

  test('Report_SumsOnlyGatedHandWrittenFiles', () {
    final report = CoverageReport.of(
      parseLcov(_lcov),
      sources: const [
        'lib/features/sales/domain/usecases/create_sale.dart',
        'lib/features/sales/presentation/providers/cart_notifier.dart',
      ],
    );

    expect(report.files, 2);
    expect(report.found, 5);
    expect(report.hit, 4);
    expect(report.percent, 80);
    expect(report.passes, isTrue);
    expect(report.describe(), contains('PASS'));
  });

  test('Report_BelowTheMinimum_Fails', () {
    final report = CoverageReport.of(
      parseLcov('''
SF:lib/features/a/domain/b.dart
DA:1,1
DA:2,0
end_of_record
'''),
      sources: const ['lib/features/a/domain/b.dart'],
    );

    expect(report.percent, 50);
    expect(report.passes, isFalse);
    expect(report.describe(), contains('FAIL'));
  });

  test('Report_FileWithoutRecord_ListedNotCounted', () {
    final report = CoverageReport.of(
      parseLcov(_lcov),
      sources: const [
        'lib/features/sales/domain/usecases/create_sale.dart',
        'lib/features/sales/presentation/providers/cart_notifier.dart',
        'lib/features/sales/domain/entities/sale_status.dart',
      ],
    );

    expect(report.unloaded, [
      'lib/features/sales/domain/entities/sale_status.dart',
    ]);
    expect(report.percent, 80);
    expect(report.passes, isTrue);
    expect(report.describe(), contains('1 gated files have no executable'));
  });

  test('Report_NothingGated_Fails', () {
    final report = CoverageReport.of(const {}, sources: const []);

    expect(report.passes, isFalse);
  });
}
