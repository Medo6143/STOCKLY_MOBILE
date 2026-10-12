import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/app.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/media/app_directories.dart';

Future<void> main() => bootstrap();

/// Resolves what must exist before the first frame, then starts the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment()
    ..ensureValidFor(releaseMode: kReleaseMode);
  final directories = await resolveAppDirectories();
  runApp(
    ProviderScope(
      // A Failure is a final answer: retry is an explicit user action.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appDirectoriesProvider.overrideWithValue(directories),
      ],
      child: const StocklyApp(),
    ),
  );
}
