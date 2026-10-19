import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a provider-hosted page (the Paymob checkout, ADR-0015) outside the
/// app: the system browser or a Custom Tab (design §14, `url_launcher`).
/// Presentation never imports the package.
abstract interface class ExternalBrowser {
  /// `true` when a browser took [uri].
  Future<bool> open(Uri uri);
}

final class UrlLauncherExternalBrowser implements ExternalBrowser {
  const new();

  @override
  Future<bool> open(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// In fake mode the hosted checkout URL does not exist
/// (`fake.stockly.invalid`), so nothing is opened; the payment is finished
/// from the debug panel instead.
final class FakeModeExternalBrowser implements ExternalBrowser {
  const new();

  @override
  Future<bool> open(Uri uri) async => true;
}

final externalBrowserProvider = Provider<ExternalBrowser>(
  (ref) => kFakeBackendEnabled
      ? const FakeModeExternalBrowser()
      : const UrlLauncherExternalBrowser(),
);
