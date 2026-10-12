import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// App directories, resolved once in `bootstrap()` (design §14).
abstract interface class AppDirectories {
  /// Private, backed-up directory for the database and queued images.
  String get supportDir;

  /// Cache directory the system may clear.
  String get tempDir;
}

final class ResolvedAppDirectories implements AppDirectories {
  const new({required this.supportDir, required this.tempDir});

  @override
  final String supportDir;

  @override
  final String tempDir;
}

/// Looks the directories up with `path_provider`.
Future<AppDirectories> resolveAppDirectories() async {
  final support = await getApplicationSupportDirectory();
  final temp = await getTemporaryDirectory();
  return ResolvedAppDirectories(supportDir: support.path, tempDir: temp.path);
}

/// Overridden in `bootstrap()` after the directory lookup.
final appDirectoriesProvider = Provider<AppDirectories>(
  (ref) => throw StateError('appDirectoriesProvider is set in bootstrap().'),
);
