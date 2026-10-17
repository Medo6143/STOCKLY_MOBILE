Read AGENTS.md fully before starting.

# Brief: mobile-6-ci-release

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/ci-release` (already checked out, based on `main` with Sprint 4 merged) · Lane: MOBILE · Contract version: **v1.5** (`docs/api/contract.md`; no mobile-facing change since v1.4)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md or the design, **stop and report** instead of guessing.

## 1. Goal and why
Sprint 6 on mobile: CI on GitHub Actions, the Android release build ready for the first shops, match confidence shown on review, and a privacy policy screen.

## 2. Scope
**You may change / create:** `lib/**`, `test/**`, `.github/workflows/**`, `android/app/build.gradle.kts` (or `.gradle`) for release signing and shrinking, `android/app/proguard-rules.pro`, `android/key.properties.example`, `.gitignore` (only to ignore `android/key.properties` and `*.jks`/`*.keystore`), `README.md`, `docs/release/android.md` (new), `docs/privacy/privacy-policy.md` (new, Arabic and English).

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/**`, `docs/api/**`, `docs/design/**`, `docs/agents/**`, `docs/sprints/**`, `android/app/src/debug/**`.

**Git and machine safety:** never run git commands that change the working tree or history. Never push. Never kill processes by image name; stop only processes you started, by PID. **Do not start the emulator and do not install or launch the app.** Never create or commit a real keystore or password; never change anything outside this repository except the tool caches.

**Environment:** in every shell, before any `flutter`/`dart` command:
```bash
export PATH="/d/dev/flutter/bin:$PATH" PUB_CACHE='D:\dev\pub-cache' GRADLE_USER_HOME='D:\dev\gradle' ANDROID_USER_HOME='D:\dev\android-user' ANDROID_HOME='D:\Android\Sdk' TEMP='D:\FLUTTER\_tmp' TMP='D:\FLUTTER\_tmp'
```

## 3. What to build
1. **CI** `.github/workflows/mobile.yml`: on push and PR; Flutter 3.47.7 pinned; `flutter pub get`, `build_runner`, `gen-l10n` + fail on untranslated messages, `flutter analyze`, `dart format --set-exit-if-changed lib test`, `flutter test --coverage` (exclude tag `live`) with a gate of **≥ 80% line coverage on `lib/features/*/domain` and `lib/features/*/presentation/providers`** (a small Dart script under `tool/` computes it from `lcov.info`; no new package), and `flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake`. Pin actions by full commit SHA with a version comment.
2. **Release build:** signing config read from `android/key.properties` (git-ignored; `key.properties.example` documents the fields) or from CI secrets as env vars; when neither exists the release build fails with a clear message (never falls back to debug signing). R8 shrinking on with the rules Flutter, Drift/sqlite, `flutter_secure_storage`, `workmanager`, `mobile_scanner` need. `--dart-define=STOCKLY_API_BASE_URL` required for release (`AppConfig.ensureValidFor` already refuses fake mode; also refuse an `http://` base URL in release, with a test). Version from `pubspec.yaml`. Steps in `docs/release/android.md` (keystore creation with `keytool`, Play Console internal testing track, the checklist).
3. **Match confidence on review:** the backend now returns trigram matches with `matchConfidence` < 0.9; show a "check this match" hint and the percent on lines below a threshold token (0.9), in both languages, with widget tests.
4. **Privacy policy:** `docs/privacy/privacy-policy.md` (Arabic and English: what is collected — account, shop data, invoice photos kept 90 days, sales; processors: the AI provider via OpenRouter receives invoice photos; no ads, no selling data; deletion requests contact placeholder), and a `PrivacyPolicyScreen` reachable from settings and the register screen, text from ARB files, 4 states not needed beyond data (static) but RTL and dark checked in tests.
5. **Coverage now:** measure; add meaningful tests until the gate passes.

## 4. Critical rules
AGENTS.md rules 34–39 and the shared rules; never weaken a test; no secrets in the repo.

## 5. Checks
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test --coverage
dart run tool/coverage_gate.dart
dart format --set-exit-if-changed lib test
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```
Also prove the release guard: `flutter build apk --release --dart-define=STOCKLY_API_BASE_URL=https://api.example.invalid` without `key.properties` must fail with your clear message (report its output).

## 6. Do not commit, push or merge.

## 7. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <summary by folder>
Check outputs: <tails of each command, test counts, coverage %>
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE
```
