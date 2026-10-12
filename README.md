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

Fake backend demo accounts (fake data only): `mona@stockly.test` (Owner) and `karim@stockly.test` (Staff), password `Stockly123`.

Android builds need NDK 28.2.13676358 (Flutter's default, required by the `jni` plugin that `path_provider_android` uses).
