# stockly-mobile

Flutter app for Stockly, an AI inventory product for small shops in Egypt. Arabic first (RTL), English too, light and dark.

Read [`AGENTS.md`](AGENTS.md) before your first change. API contract: [`docs/api/contract.md`](docs/api/contract.md). Design: [`docs/design/`](docs/design/). Brand: [`brand/`](brand/).

The backend lives in `stockly-backend` (ADR-0011 there).

## Run

Flutter 3.47.7 stable (Dart 3.13.5), Android only.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n

# Without the backend: the fake backend answers every request (debug only).
flutter run --dart-define=STOCKLY_BACKEND=fake

# Against the API (scheme and host only; the app adds /api/...).
flutter run --dart-define=STOCKLY_BACKEND=real --dart-define=STOCKLY_API_BASE_URL=http://10.0.2.2:5000

# Checks
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```

### Run in fake mode

```bash
flutter run --dart-define=STOCKLY_BACKEND=fake
```

The fake backend lives in memory: every restart starts again from the seed. Seed accounts (fake data only, shop `صيدلية الشفاء`, Pharmacy):

| Role | Email | Password |
|---|---|---|
| Owner | `mona@stockly.test` | `Stockly123` |
| Staff | `karim@stockly.test` | `Stockly123` |

Like the real API (contract v1.4), 5 wrong passwords in a row lock an account for 15 minutes, and login and register each allow 10 requests per minute.

The shop starts with an Arabic pharmacy catalogue of 31 products (one archived, several at or below their low-stock level, `نوفالجين` below zero), each quantity backed by stock movements. Barcodes to try: `6221234567890` (`بنادول اكسترا`, strip) and `6221234567906` (its box). The box of `بنادول اكسترا` counts as used on an invoice, so deleting it shows `ProductUnit.InUse`. Only the Owner sees adjust, count, archive and the opening stock field.

Invoices: the seed has one invoice in every status (two to review, one with a total that does not match and a line without a product, one with no lines read; one confirmed; one failed; one still being read, which turns "Needs review" about 6 seconds after start). A new scan is read after 6 seconds: in turn a pharmacy invoice that needs review, a clean one, and an unreadable photo that fails. Up to 10 scans a minute and 50 a day (Cairo day) are accepted. The upload queue works offline (switch the fake backend offline in the panel) and in the background only against the real API.

Confirming an invoice receives its stock (boxes are counted in strips) and creates its new products; confirming again changes nothing. Sales: the quick sale (**New sale** on the home screen or the sales tab) takes barcodes typed or sent by a Bluetooth/USB scanner (each ends with Enter; the same barcode twice adds 1), the camera scanner, or a product search; a sale that takes stock below zero is recorded with a warning. The home screen (dashboard) is computed from the fake data: today's sales by the Cairo day, low and negative stock, invoices to review, and the confirmed lines that expire soon (`بروفين 400` within 60 days, `فيتامين سي 1000` within 90). When a sale is sent while the fake backend is offline its outcome is unknown: the cart stays locked with Retry and Discard, also after a restart.

Debug panel: sign in, open **Settings** and **long-press the version text** at the bottom (fake mode only). It can switch the device offline, fail the next request with a chosen error code, expire the access token now, suspend the shop, turn the account lockout and the login/register rate limit on or off, and use up the daily scan quota.

### Screens

The app has five tabs: **Home** (dashboard), **Products**, **Invoices**, **Sales** and **Profile**. The home screen and the profile open with a navy gradient header (shop name on the home screen, avatar with initials, name, email, phone and role on the profile) with cards overlapping its edge; dashboard numbers count up. Lists are rounded cards with a tinted badge and soft status chips, forms group their fields in titled cards with full-width pill buttons, and loading shows shimmering skeletons shaped like the content. Settings (language, theme, version, sign out) moved under **Profile → Settings** (`/profile/settings`; the old `/settings` link redirects there), so the debug panel is at **Profile → Settings**, long-press the version. Pushed screens slide in from the end edge (the left in Arabic), tabs fade through, and invoice confirm and recorded sales show an animated check. With the system's "Remove animations" / "Reduce motion" on, every animation shows its final frame.

### Live API test

`test/live/live_api_test.dart` (tag `live`) runs the app's real Dio stack, data sources and repositories against a running backend: register, login, `me`, a product with opening stock, a unit, an adjustment, a stock count, the low-stock list, movements, a sale of the product and the same sale again (`200`, same id), the sales list and detail, the dashboard summary and expiring-soon list, the barcode lookup, refresh and logout, once in Arabic and once in English. Without the define it is skipped, so `flutter test` stays offline.

```bash
flutter test --tags live --dart-define=STOCKLY_LIVE_API=http://127.0.0.1:5000
```

### Native splash

The native launch screen comes from `flutter_native_splash.yaml` and the PNGs in `assets/splash/`, rendered from the outline-only `mark_outline_*.svg` next to them. After changing them:

```bash
dart run flutter_native_splash:create
```

Android builds need NDK 28.2.13676358 (Flutter's default, required by the `jni` plugin that `path_provider_android` uses).
