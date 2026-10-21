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

# Against the API (scheme and host only; the app adds /api/...).
# The default is http://10.0.2.2:5000, the development machine seen from the Android emulator.
flutter run --dart-define=STOCKLY_API_BASE_URL=http://10.0.2.2:5000

# Checks (the same as CI, .github/workflows/mobile.yml)
flutter analyze
dart format --set-exit-if-changed lib test
flutter test --coverage --exclude-tags live
dart run tool/coverage_gate.dart   # >= 80% lines on lib/features/*/domain and */presentation/providers
flutter build apk --debug
```

CI runs on every push and pull request with Flutter 3.47.7 and also fails on untranslated ARB messages (`build/untranslated_messages.json` must be `{}`).

### Release

Release builds need upload signing (`android/key.properties` from `android/key.properties.example`, or the `STOCKLY_UPLOAD_*` variables) and an `https` `STOCKLY_API_BASE_URL`; without them the build stops with a message, it never signs with the debug key. Steps, keystore creation and the Play Console internal track: [`docs/release/android.md`](docs/release/android.md). Privacy policy (also in the app under Profile → Privacy policy and on the register screen): [`docs/privacy/privacy-policy.md`](docs/privacy/privacy-policy.md).

### Screens

The app has five tabs: **Home** (dashboard), **Products**, **Invoices**, **Sales** and **Profile**. The home screen and the profile open with a navy gradient header (shop name on the home screen, avatar with initials, name, email, phone and role on the profile) with cards overlapping its edge; dashboard numbers count up. Lists are rounded cards with a tinted badge and soft status chips, forms group their fields in titled cards with full-width pill buttons, and loading shows shimmering skeletons shaped like the content. Settings (language, theme, version, sign out) moved under **Profile → Settings** (`/profile/settings`; the old `/settings` link redirects there), so the debug panel is at **Profile → Settings**, long-press the version. Pushed screens slide in from the end edge (the left in Arabic), tabs fade through, and invoice confirm and recorded sales show an animated check. The navy strip behind the status bar stays fixed with light icons, so header content never scrolls under the clock. **Profile** shows "Your plan" under the shop card (plan, price, today's scans against the quota with a bar, members, renewal date, and a banner while a payment is pending) and opens **Plans** (`/profile/plans`): the Owner chooses a paid plan and pays in a sheet (card, wallet or kiosk); Staff see the plans read-only. A card or wallet payment opens the provider's page in the browser, then **Payment** (`/profile/payments/:id`) asks the server every 3 seconds until it is paid, failed or expired (and again when the app comes back to the foreground); a kiosk payment shows the reference to pay. **Profile → Payments** (`/profile/payments`) lists every payment with its status. On the home screen the Owner sees an "Upgrade" card once today's scans reach 80 % of the quota. On review, a line matched to a product with less than 90% confidence shows a "Check this match" pill with the percent. With the system's "Remove animations" / "Reduce motion" on, every animation shows its final frame.

### Live API test

`test/live/live_api_test.dart` (tag `live`) runs the app's real Dio stack, data sources and repositories against a running backend: register, login, `me`, a product with opening stock, a unit, an adjustment, a stock count, the low-stock list, movements, a sale of the product and the same sale again (`200`, same id), the sales list and detail, the dashboard summary and expiring-soon list, the plans and the new shop's subscription (B1, B2; no checkout, since no real payment can be made from a test), the barcode lookup, refresh and logout, once in Arabic and once in English. Without the define it is skipped, so `flutter test` stays offline.

```bash
flutter test --tags live --dart-define=STOCKLY_LIVE_API=http://127.0.0.1:5000
```

### Native splash

The native launch screen comes from `flutter_native_splash.yaml` and the PNGs in `assets/splash/`, rendered from the outline-only `mark_outline_*.svg` next to them. After changing them:

```bash
dart run flutter_native_splash:create
```

Android builds need NDK 28.2.13676358 (Flutter's default, required by the `jni` plugin that `path_provider_android` uses).
