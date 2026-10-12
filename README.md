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

Debug panel: sign in, open **Settings** and **long-press the version text** at the bottom (fake mode only). It can switch the device offline, fail the next request with a chosen error code, expire the access token now, suspend the shop, and turn the account lockout and the login/register rate limit on or off.

### Native splash

The native launch screen comes from `flutter_native_splash.yaml` and the PNGs in `assets/splash/`, rendered from the outline-only `mark_outline_*.svg` next to them. After changing them:

```bash
dart run flutter_native_splash:create
```

Android builds need NDK 28.2.13676358 (Flutter's default, required by the `jni` plugin that `path_provider_android` uses).
