import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockly/core/platform/external_browser.dart';

/// Pages of the payment provider: both browsers take them.
const List<String> providerPages = [
  'https://eg.checkout.paymob.com/?publicKey=egy_pk_test_x&clientSecret=y',
  'https://accept.paymob.com/api/acceptance/iframes/1?payment_token=z',
  'https://accept.paymobsolutions.com/api/acceptance/wallet/redirect',
];

/// Anything else: both browsers refuse it, so fake mode catches a bad URL
/// the way the real app does (Liskov).
const List<String> refusedPages = [
  'http://eg.checkout.paymob.com/?publicKey=x',
  'intent://scan/#Intent;scheme=zxing;package=com.evil;end',
  'file:///data/data/com.stockly.stockly/databases/stockly.db',
  'tel:+201001234567',
  'https://paymob.com.evil.io/pay',
  'https://evilpaymob.com/pay',
  'https://example.com/payment-done',
  // The fake backend's host, but not over its scheme.
  'http://fake.stockly.invalid/pay/1',
];

void main() {
  late List<Uri> launched;

  UrlLauncherExternalBrowser browser({bool throws = false}) =>
      UrlLauncherExternalBrowser(
        launcher: (uri) async {
          if (throws) {
            throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
          }
          launched.add(uri);
          return true;
        },
      );

  setUp(() => launched = []);

  test('PaymobOverHttps_Opened', () async {
    for (final url in providerPages) {
      expect(await browser().open(Uri.parse(url)), isTrue, reason: url);
    }
    expect(launched, hasLength(providerPages.length));
  });

  test('OtherSchemesOrHosts_NeverHandedToTheSystem', () async {
    for (final url in refusedPages) {
      expect(await browser().open(Uri.parse(url)), isFalse, reason: url);
    }
    expect(launched, isEmpty);
  });

  test('LauncherThrows_FalseInsteadOfAnException', () async {
    final opened = await browser(throws: true)
        .open(Uri.parse('https://eg.checkout.paymob.com/?publicKey=x'));

    expect(opened, isFalse);
  });
}
