import 'dart:io';

/// Hand-written Dart files under `lib/` (generated code excluded), with
/// paths relative to the project root and `/` separators.
List<File> handWrittenLibFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('.g.dart'))
        .where((f) => !f.path.endsWith('.freezed.dart'))
        .where((f) => !normalizedPath(f).startsWith('lib/l10n/generated/'))
        .toList();

String normalizedPath(File file) => file.path.replaceAll(r'\', '/');

/// The `import` targets of [source].
Iterable<String> importsOf(String source) => RegExp(
  r'''^import\s+['"]([^'"]+)['"]''',
  multiLine: true,
).allMatches(source).map((m) => m.group(1)!);
