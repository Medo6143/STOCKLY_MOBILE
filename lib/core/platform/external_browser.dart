import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stockly/core/config/app_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a provider-hosted page (the Paymob checkout, ADR-0015) outside the
/// app: the system browser or a Custom Tab (design §14, `url_launcher`).
/// Presentation never imports the package.
abstract interface class ExternalBrowser {
  /// `true` when a browser took [uri]. Never throws.
  Future<bool> open(Uri uri);
}

/// Hands a URI to the system.
typedef UrlLauncher = Future<bool> Function(Uri uri);

final class UrlLauncherExternalBrowser implements ExternalBrowser {
  const new({this._launcher = _launchExternally});

  final UrlLauncher _launcher;

  /// The checkout URL comes from the server, so it is untrusted: only an
  /// `https` page of the payment provider is handed to the system. Any
  /// other scheme (`intent:`, `file:`, `tel:`) or host is refused.
  static const String _https = 'https';
  static const List<String> _providerDomains = [
    'paymob.com',
    // Paymob's older domain, still used by some wallet redirects.
    'paymobsolutions.com',
  ];

  static bool isProviderPage(Uri uri) =>
      uri.scheme == _https &&
      _providerDomains.any(
        (domain) => uri.host == domain || uri.host.endsWith('.$domain'),
      );

  static Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Future<bool> open(Uri uri) async {
    if (!isProviderPage(uri)) {
      return false;
    }
    try {
      return await _launcher(uri);
    } on PlatformException {
      // No browser can handle it: the caller says so and offers it again.
      return false;
    }
  }
}

/// In fake mode the hosted checkout URL does not exist
/// (`fake.stockly.invalid`), so nothing is opened; the payment is finished
/// from the debug panel instead. It answers like
/// [UrlLauncherExternalBrowser] (a URL the real app refuses is refused here
/// too), plus the fake backend's own checkout host.
final class FakeModeExternalBrowser implements ExternalBrowser {
  const new();

  /// The fake backend's base: its hosted checkout lives there.
  static final Uri _fakeCheckout = Uri.parse(AppConfig.fakeApiBaseUrl);

  @override
  Future<bool> open(Uri uri) async =>
      UrlLauncherExternalBrowser.isProviderPage(uri) ||
      (uri.scheme == _fakeCheckout.scheme && uri.host == _fakeCheckout.host);
}

final externalBrowserProvider = Provider<ExternalBrowser>(
  (ref) => kFakeBackendEnabled
      ? const FakeModeExternalBrowser()
      : const UrlLauncherExternalBrowser(),
);
