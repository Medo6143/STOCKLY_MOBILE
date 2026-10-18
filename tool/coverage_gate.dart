import 'dart:io';

/// The CI coverage gate (brief mobile-6 §3.1): line coverage of
/// `lib/features/*/domain` and `lib/features/*/presentation/providers`,
/// read from `coverage/lcov.info`, must be at least [minimumPercent].
///
/// Generated files (`*.g.dart`, `*.freezed.dart`) are left out: they are
/// build_runner output, not code written here. Gated files without an lcov
/// record are counted and reported: the VM writes no record for a library
/// without executable lines (enums, interfaces, freezed declarations).
///
/// ```bash
/// flutter test --coverage
/// dart run tool/coverage_gate.dart [path/to/lcov.info]
/// ```
Future<void> main(List<String> arguments) async {
  final lcovPath = arguments.isEmpty ? defaultLcovPath : arguments.first;
  final lcov = File(lcovPath);
  if (!lcov.existsSync()) {
    stderr.writeln(
      'Coverage gate: $lcovPath not found. Run '
      '`flutter test --coverage` first.',
    );
    exitCode = 1;
    return;
  }
  final records = parseLcov(await lcov.readAsString());
  final sources = Directory(libDirectory)
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => normalizePath(file.path))
      .where(isGatedSource)
      .toList();
  final report = CoverageReport.of(records, sources: sources);
  stdout.writeln(report.describe());
  if (!report.passes) {
    exitCode = 1;
  }
}

/// Where `flutter test --coverage` writes its report.
const String defaultLcovPath = 'coverage/lcov.info';

/// The package's source folder.
const String libDirectory = 'lib';

/// The gate, in percent of executable lines hit.
const double minimumPercent = 80;

const List<String> _generatedSuffixes = ['.g.dart', '.freezed.dart'];
const String _dartSuffix = '.dart';

final RegExp _gatedFolder = RegExp(
  '^lib/features/[^/]+/(domain|presentation/providers)/',
);

/// `lib\a\b.dart` → `lib/a/b.dart`; drops a leading `./`.
String normalizePath(String path) {
  final slashes = path.replaceAll(r'\', '/');
  return slashes.startsWith('./') ? slashes.substring(2) : slashes;
}

/// Whether [path] (normalized, relative to the package) is gated.
bool isGatedSource(String path) =>
    path.endsWith(_dartSuffix) &&
    !_generatedSuffixes.any(path.endsWith) &&
    _gatedFolder.hasMatch(path);

/// Lines found and hit for one source file.
final class FileCoverage {
  const new({required this.found, required this.hit});

  final int found;
  final int hit;
}

/// Parses an lcov report into line coverage per normalized source path.
/// Reads `DA:` lines (not the `LF`/`LH` totals, which some writers omit).
Map<String, FileCoverage> parseLcov(String content) {
  final result = <String, FileCoverage>{};
  String? source;
  final lines = <int, bool>{};
  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      source = normalizePath(line.substring(3));
      lines.clear();
    } else if (line.startsWith('DA:') && source != null) {
      final fields = line.substring(3).split(',');
      final number = int.tryParse(fields.first);
      final hits = fields.length > 1 ? int.tryParse(fields[1]) : null;
      if (number != null && hits != null) {
        lines[number] = (lines[number] ?? false) || hits > 0;
      }
    } else if (line == 'end_of_record' && source != null) {
      final previous = result[source];
      result[source] = FileCoverage(
        found: lines.length + (previous?.found ?? 0),
        hit: lines.values.where((hit) => hit).length + (previous?.hit ?? 0),
      );
      source = null;
    }
  }
  return result;
}

/// The gate's verdict over the gated files.
final class CoverageReport {
  const new({
    required this.found,
    required this.hit,
    required this.files,
    required this.unloaded,
  });

  /// Sums the gated records; [sources] are the gated files on disk, used
  /// to find the ones no test loaded.
  factory of(
    Map<String, FileCoverage> records, {
    required List<String> sources,
  }) {
    final gated = {
      for (final entry in records.entries)
        if (isGatedSource(entry.key)) entry.key: entry.value,
    };
    final unloaded = sources.where((path) => !gated.containsKey(path)).toList()
      ..sort();
    return CoverageReport(
      found: gated.values.fold(0, (sum, file) => sum + file.found),
      hit: gated.values.fold(0, (sum, file) => sum + file.hit),
      files: gated.length,
      unloaded: unloaded,
    );
  }

  final int found;
  final int hit;
  final int files;

  /// Gated files on disk without an lcov record (informational).
  final List<String> unloaded;

  double get percent => found == 0 ? 0 : hit * 100 / found;

  bool get passes => found > 0 && percent >= minimumPercent;

  String describe() {
    final buffer = StringBuffer(
      'Coverage gate (lib/features/*/domain, '
      'lib/features/*/presentation/providers): '
      '$hit/$found lines in $files files = ${percent.toStringAsFixed(2)}% '
      '(minimum ${minimumPercent.toStringAsFixed(0)}%).',
    );
    if (unloaded.isNotEmpty) {
      buffer.write(
        '\n${unloaded.length} gated files have no executable lines '
        '(no lcov record).',
      );
    }
    buffer.write(passes ? '\nPASS' : '\nFAIL');
    return buffer.toString();
  }
}
