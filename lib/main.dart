import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:stockly/app.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:stockly/core/media/app_directories.dart';
import 'package:stockly/core/platform/native_splash.dart';
import 'package:stockly/features/invoices/data/sync/background_sync_entrypoint.dart';
import 'package:workmanager/workmanager.dart' show Workmanager;

Future<void> main() => bootstrap();

/// Resolves what must exist before the first frame, then starts the app.
/// [overrides] replace providers for a local tool (for example an adapter
/// that answers in place of the network); the app passes none.
Future<void> bootstrap({List<Override> overrides = const []}) async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // The native splash stays until the animated splash's first frame.
  PluginNativeSplash.preserve(binding);
  final config = AppConfig.fromEnvironment()
    ..ensureValidFor(releaseMode: kReleaseMode);
  final directories = await resolveAppDirectories();
  // The background scan upload (design §6.5) runs in its own isolate.
  await Workmanager().initialize(scanSyncCallbackDispatcher);
  runApp(
    ProviderScope(
      // A Failure is a final answer: retry is an explicit user action.
      retry: (_, _) => null,
      overrides: [
        appConfigProvider.overrideWithValue(config),
        appDirectoriesProvider.overrideWithValue(directories),
        ...overrides,
      ],
      child: const StocklyApp(),
    ),
  );
}
