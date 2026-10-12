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

- Brief: `docs/agents/briefs/mobile-2b-splash-auth.md` (contract v1.4: lockout and rate-limit codes added since 2a; splash-minimum fix for `authRedirect`; PNG exports via headless Chrome, no downloads). Branch `feature/splash-auth`. Worker: general-purpose agent (background). State: started.
