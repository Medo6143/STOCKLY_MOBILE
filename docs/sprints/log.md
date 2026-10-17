# stockly-mobile log

Running record of the mobile lane: which agent, brief path, verification result, commit hashes, decisions. Newest at the bottom. Orchestration guide: `stockly-backend/docs/agents/ORCHESTRATION.md`.

## Setup (2026-10-12)

- Repository created from `D:\FLUTTER\stockly-mobile-assets` (brand/ byte-identical, AGENTS.mobile.md → AGENTS.md with a shared-rules section, structure.mobile.md → docs/structure.md), plus `CLAUDE.md` (`@AGENTS.md`), `.gitignore`, `.editorconfig`, `.gitattributes`, contract v1.2 copy, brief template.
- Toolchain: Flutter 3.47.7 stable at `D:\dev\flutter` (Dart 3.13.5); `flutter doctor` Android toolchain green (SDK 36.1.0 at `C:\Users\medow\AppData\Local\Android\Sdk`, cmdline-tools 23.0). Caches on D: (`PUB_CACHE`, `GRADLE_USER_HOME`, `ANDROID_USER_HOME`).

## Brief 1: docs/design/frontend.md

- Brief: `docs/agents/briefs/mobile-design-frontend.md`. Worker: general-purpose agent (background).
- Report: "AGENTS.md read: yes", contract deviations NONE, only `docs/design/frontend.md` (1,485 lines, 16 sections, 6 Mermaid blocks; the worker parsed them with mermaid 11.4.1).
- Orchestrator verification: `git status` shows only `docs/design/`; script check: all 48 error codes used exist in contract v1.2 §9 and every catalogue code is handled; every endpoint path used is in the contract; read §4 networking in full (refresh queue: single-flight, cross-isolate lease, stale-token check, refresh once / retry once, logout allowed when suspended): matches contract §1.4 and A4. Accepted as draft for product-owner review (checkpoint 2).
- Deviation from the brief's wording (for review): fakes are a Dio `HttpClientAdapter` (`FakeBackendAdapter`), not fake repositories, so all real code above Dio runs in fake mode (SOLID L by construction).
- Packages that need approval (stop condition 3, asked at checkpoint 2): image_picker, flutter_image_compress, path_provider, drift_flutter + sqlite3_flutter_libs, drift_dev (dev), freezed_annotation + json_annotation, mobile_scanner (Sprint 4).
- Incident: to stop a temporary local web server the worker ran `taskkill /F /IM python.exe`, which kills every Python process on the machine. No repository files affected. Reported to the product owner. Future briefs forbid machine-wide process kills.
- 14 open questions in `docs/design/frontend.md` §15.

## Checkpoint 2 (2026-10-12)

- `frontend.md` approved; decisions applied (`uuid` behind `UuidGenerator`, fake backend built incrementally, native splash outline only, PNG exports via a CLI rasterizer, packages approved, `Retry-After` on daily quota from contract v1.3). Commit `595f55c`.
- Contract copy updated to v1.3 (backend `main` `e8b84cb`).

## Brief 2a: foundation

- Brief: `docs/agents/briefs/mobile-2a-foundation.md` (contract v1.3 §1, A1–A5, §3, §4, §9 copied). Branch `feature/foundation`. Worker: general-purpose agent (background).
- Report: "AGENTS.md read: yes", contract deviations NONE; all checks green except the debug APK (NDK 28.2.13676358 missing).
- Environment fix (product owner approved): Android SDK moved to `D:\Android\Sdk`, NDK 28.2.13676358 installed, `ANDROID_HOME` and `ANDROID_AVD_HOME` set; AVD QA_Pixel_7 (Android 16, API 36) skin path fixed, boots, listed by `flutter devices`.
- Orchestrator verification: build_runner OK; gen-l10n OK (no untranslated); `flutter analyze` no issues; `flutter test` 242 passed; `dart format` 0 changed; `flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake` built (163 MB); installed on QA_Pixel_7, starts without crash, shows the placeholder home in the device language (en-US emulator, design §8.2).
- Worker decisions accepted: go_router 17 (18 needs unapproved packages); plain `Interceptor` for refresh (queued interceptor would deadlock; single-flight still tested); session DTOs in `core/session`; `build.yaml`; runtime release check in `bootstrap()`; applicationId `com.stockly.stockly`.
- Carried into 2b: splash minimum vs `authRedirect` (redirect needs a "splash finished" input).

## Brief 2b: splash and auth screens

- Brief: `docs/agents/briefs/mobile-2b-splash-auth.md` (contract v1.4: lockout and rate-limit codes added since 2a; splash-minimum fix for `authRedirect`; PNG exports via headless Chrome, no downloads). Branch `feature/splash-auth`. Worker: general-purpose agent (background).
- Report: "AGENTS.md read: yes", contract deviations NONE.
- Orchestrator verification: scope ok; build_runner, gen-l10n (untranslated `{}`), `flutter analyze` no issues, `flutter test` 408 passed, `dart format` 0 changed, debug APK built.
- Decisions accepted: router-owned splash gate (`authRedirect(splashFinished:)`); 3 s maximum falls back to the cached session; restore-result guard; `flutter_native_splash` as a runtime dependency behind `NativeSplash`; single Ticker for loading dots; architecture exception widened so `settings` may import the app-wide session providers (design §2.2); `AppVersion` constant checked against pubspec; fake rate limit per adapter; settings pending-scans warning deferred until the scan queue exists.
- For the brand (non-blocking): native mark is ~148 dp vs 132 dp for the animated mark on API 36, so the hand-off is not pixel-exact.
- Note: the worker saw other input on the emulator while testing; that was the product owner using the live app (`D:\FLUTTER\_wt\mobile-live`).
- Merged: `630a92d`. Live app on QA_Pixel_7 relaunched from `main` (new packages and native splash): native outline splash → animated splash → login screen.

## Brief 2c: product screens

- Brief: `docs/agents/briefs/mobile-2c-products.md` (contract v1.4 §1, P1–P12, §3, §5, product codes; backend P1–P11 now implemented). Branch `feature/products`. Worker: general-purpose agent (background).
- Report: "AGENTS.md read: yes", contract deviations NONE, no new packages.
- Orchestrator verification: scope ok (no `docs/`, `android/` or brand changes by the worker); build_runner OK; gen-l10n OK (untranslated `{}`); `flutter analyze` no issues; `flutter test` 660 passed (408 before); `dart format` 0 changed; debug APK built. Read the data source and repository (paths and query names match the backend `ProductsController`), the form notifier, and every edited test: no assertion removed or weakened. Grep for `left`/`right`, `DateTime.now`, `double`, `Colors.`, `TODO`: none.
- Decisions accepted: architecture exceptions widened (products may read `isOwnerProvider`, design §2.3; domain may import `core/pagination/paged.dart`, design §1.4); `PagedResponseDto` in `core/network`; list filters read from the route query on entry; edit, unit, adjustment and count screens reuse `productDetailProvider`; writes invalidate list, detail and movements; the fake follows the backend's validation order (403 before validation, shape → precision → not found → domain codes).
- Note: P12 (barcode lookup) is wired through data, use case, provider and fake, but no screen uses it yet; the quick-sale screen (Sprint 4) will. The backend implements it in Sprint 4.
- Commits: `11c651e`, `2b5d59d`, `313e6d9`, `38db4f6`.

## Real backend on the emulator (2026-10-17)

- Debug-only `network_security_config` allowing cleartext to `10.0.2.2` and `localhost` (`148f8d7`, merged `a253efb`). Release builds keep the platform default.
- App from `main` (real backend, `http://10.0.2.2:5000`) on QA_Pixel_7 against the API from backend `main`: register → `201`, product list → `200`, create product with opening stock 24 → `201`, product detail from the database. English UI.

## Brief 3: scan flow

- Brief: `docs/agents/briefs/mobile-3-scan-flow.md`. Branch `feature/scan-flow`. Worker: general-purpose agent (background); resumed once after a network error, no work lost.
- Report: "AGENTS.md read: yes", contract deviations NONE; packages added are all approved in design §14.
- Orchestrator verification: build_runner OK; gen-l10n (untranslated `{}`); `flutter analyze` no issues; `dart format` 0 changed; `flutter test` 931 passed, 2 skipped (live). **Live API test** (`flutter test --tags live test/live --dart-define=STOCKLY_LIVE_API=http://127.0.0.1:5000`) against the backend from `main`: `FullFlow_ar` and `FullFlow_en` passed (register, login, me, product with opening stock, unit, adjust, count, low stock, movements, refresh, logout, localized ProblemDetails).
- Read the architecture-test changes: narrow, design-backed exceptions (`invoices` as session consumer; `invoices` → `products_providers.dart`; `settings` → `pending_scans_providers.dart`). No assertion removed.
- Decisions accepted: upload service in invoices data layer; background entrypoint no-op in fake builds; domain `InvoicePhotoSource` separate from `core/media`; cancellable polling (31 polls / 60 s); review auto-opens once; unresolved lines checked on the device before I4; fake rate limit 10/min, quota 50/Cairo day, every third fake scan fails; no manifest change for `image_picker`.
- Live tag: `dart_test.yaml` declares `live`; the test skips without `STOCKLY_LIVE_API` (a config exclude would also block `--tags live`). Accepted.
- Commits: `11fc77e`, `8bca0de`, `9132c70`, `9b3316e`, `0d3c7de`.

## Brief 4: confirm, sales, dashboard

- Brief: `docs/agents/briefs/mobile-4-confirm-sales-dashboard.md`. Branch `feature/confirm-sales-dashboard`. Worker: general-purpose agent (background); resumed once after a network error.
- Sent back once: the fake D2 left out already-expired lines while the real backend includes them (SOLID L). Fixed: fake D2/D1 match the backend order and window; expired lines marked with a danger chip.
- Orchestrator verification: build_runner OK; gen-l10n (untranslated `{}`); `flutter analyze` no issues; `dart format` 0 changed; `flutter test` 1,131 passed, 2 skipped (live). **Live API test** against backend `main` (with Sprint 4): `FullFlow_ar` and `FullFlow_en` passed, now including sale + idempotent repeat, S2, S3, D1, D2 and P12.
- Decisions accepted: pending sale row written before the first send; unknown outcome locks the cart; reopened cart shows a summary only (no schema change); discard after a warning dialog; S2 filters send only `from`; unit picker loads P2 on demand; PlaceholderScreen removed; narrow architecture exceptions for cross-feature invalidation (design §2.3, §6.8); `mobile_scanner` without manifest change.
- Process note: the worker once ran `git checkout -- lib/core/config/limits.dart` (reverting only its own appended lines), which the brief forbids. Reminded; no other tree-changing git command.

## Brief 5: design refresh, profile, animation (product owner request)

- Requested by the product owner after seeing the app on the emulator (2026-10-17): modern design, a standalone profile page, animation. Brief `docs/agents/briefs/mobile-5-design-refresh.md`, branch `feature/design-refresh`.
- Report: "AGENTS.md read: yes", contract deviations NONE, no new packages.
- Orchestrator verification: build_runner OK; gen-l10n (untranslated `{}`); `flutter analyze` no issues; `dart format` 0 changed; `flutter test` 1,209 passed, 2 skipped (live); live API test (ar, en) passed against backend `main`. Changed assertions: only the 5th tab label (`navSettings` → `navProfile`) and the redirect expectation for `/settings` (now `legacySettings`; a new assertion added for `/profile/settings`).
- Decisions accepted: profile lives in the settings feature; `dashboard` added to session consumers (shop name in the hero header); push slides in from the end edge (right in LTR, left in RTL); shimmer on a widget-owned controller (the `Animate` widget left pending timers in tests); light hero uses a mint glow because navy equals light ink; success feedback as an animated check snackbar; AsyncStateView keeps content mounted during refresh.
- Open: the profile shop card shows name, type and role only (A5 has no governorate/address/phone; would need a contract change). Derived design tokens await brand approval.
