Read AGENTS.md fully before starting.

# Brief: mobile-3-scan-flow

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/scan-flow` (already checked out) · Lane: MOBILE · Contract version: **v1.4** (`docs/api/contract.md`)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md, the design or the contract, **stop and report** instead of guessing.

## 1. Goal and why
Finish the Sprint 3 mobile scope: the owner photographs a supplier invoice, it is queued offline and uploaded, the app waits for the AI extraction, and the owner reviews and edits the lines. Products and auth are already done (see `docs/sprints/log.md`). The backend is building I1–I4 right now with exactly this contract, so the app must work unchanged against the real API. Also add an opt-in live API smoke test that proves the app's real data sources talk to a running backend.

## 2. Scope
**You may change / create:** `lib/**`, `test/**`, `pubspec.yaml`/`pubspec.lock` (only packages approved in `docs/design/frontend.md` §14), `README.md` (run section only), `android/app/src/main/AndroidManifest.xml` only for the camera permission/queries that `image_picker` needs.

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/**`, `docs/**` (read only), `android/app/src/debug/**`, `.gitignore`, `.editorconfig`, `.gitattributes`.

**Git and machine safety:** never run git commands that change the working tree or history (`checkout`, `reset`, `stash`, `commit`, `merge`, `push`). To undo your own edit, edit the file back. Never kill processes by image name; stop only processes you started, by PID. **Do not start the Android emulator and do not install or launch the app** (the product owner asked for this). Never change anything outside this repository except the tool caches below.

**Environment:** in every shell, before any `flutter`/`dart` command:
```bash
export PATH="/d/dev/flutter/bin:$PATH" PUB_CACHE='D:\dev\pub-cache' GRADLE_USER_HOME='D:\dev\gradle' ANDROID_USER_HOME='D:\dev\android-user' ANDROID_HOME='D:\Android\Sdk' TEMP='D:\FLUTTER\_tmp' TMP='D:\FLUTTER\_tmp'
```

## 3. Critical rules
Full rules: `AGENTS.md`. Copied here:
- 34. Every screen: loading, empty, error, data with `AsyncStateView`.
- 35. No hardcoded strings, colors, sizes or durations.
- 36. Directional APIs only.
- 37. Immutable freezed state; no business logic in widgets.
- 38. Tokens only in secure storage; no API keys in the app.
- 39. Reduce motion: the processing animation shows its final frame.
- Layers: presentation never imports Dio, Drift or data classes; repositories return `Result<T, Failure>`.
- Shared: money/quantity/factor values are `Decimal` sent as strings with the contract scales; switch on `code` only; the shop comes from the token; no dead code; never weaken a test.
- Rule 20 / ADR-0006: every scan has a client-generated `clientRequestId` (v4 UUID through `UuidGenerator`) that is stored with the queued row **before** the first upload and reused on every retry; "Scan again" after `Failed` uses a **new** id.

## 4. Design sections you implement (binding: `docs/design/frontend.md`)
- §6 offline scan queue in full: capture (§6.1, `InvoiceImageSource` + `ImageCompressor`: long edge 2000 px, JPEG 80), Drift schema (§6.2), states (§6.3), upload and response handling including 409/413/429/`Retry-After`/quota (§6.4), sync triggers with `connectivity_plus` + `workmanager` (§6.5), what the user sees (§6.6), session changes (§6.7).
- §11 Sprint 3 invoice screens exactly as listed: `InvoiceListScreen`, `ScanCaptureScreen`, `ScanQueueScreen`, `InvoiceDetailScreen` with `InvoiceProcessingView` (poll I3 every 2 s up to 60 s), `InvoiceConfirmedView`, `InvoiceFailedView`, `InvoiceReviewScreen`, `InvoiceLineEditorScreen` with `ProductPickerSheet`, plus the "Invoice review rules" under the table. Confirm (I5) is Sprint 4: no confirm button yet.
- §1 layers for the `invoices` feature, §2 providers, §3 routes (already declared: replace the placeholders), §5 decimals, §8 l10n (ar is the template; every new key in both files).
- Settings: add the pending-scans warning on sign out (§6.7), which 2b deferred until the queue existed.
- §12 fake backend: `FakeInvoicesHandler` for I1–I4 with the contract's validation, idempotency by `clientRequestId`, 413 / 429 + `Retry-After` / `Scan.DailyQuotaExceeded`, a simulated `Processing` → `NeedsReview` (or `Failed`) transition driven by the fake clock, matching against the fake product seed, I4 rules (`Invoice.NotEditable`, `Invoice.LineProductRequired`, `Invoice.UnitNotOfProduct`, max 100 lines, server `lineTotal` rounded to 2 decimals away from zero). Seed a few invoices in every status. Contract fixture tests for I1–I4 under `test/contract/`.
- Packages: `image_picker`, `flutter_image_compress`, `connectivity_plus`, `workmanager` are approved (§14); add the ones not yet in `pubspec.yaml`. Anything else: stop and report.

## 5. Live API smoke test (connects the app to the backend)
Add `test/live/live_api_test.dart`, tagged `live` (add the tag to `dart_test.yaml` and **exclude it from the default run**, so `flutter test` stays offline). It reads the base URL from `--dart-define=STOCKLY_LIVE_API` and skips with a clear message when it is not set. Using the app's **real** Dio setup, interceptors, data sources and repositories (not the fake adapter), it must: register a new shop with a random email → log in → `me` → create a product with opening stock → add a unit → adjust → stock count → low-stock list contains it → movements newest first → refresh the token → log out; once with `Accept-Language: ar` and once with `en`, checking that ProblemDetails `title`/`detail` arrive in the requested language for one failing request (e.g. duplicate barcode). Tokens go through an in-memory token store in the test, not secure storage. Document how to run it in `README.md`:
```bash
flutter test --tags live --dart-define=STOCKLY_LIVE_API=http://127.0.0.1:5000
```
Do not try to start the backend yourself; the orchestrator runs this test.

## 6. Tests
Unit tests for every use case and notifier (queue state machine incl. retry/backoff and session change, upload response handling for 202/200-repeat/400/401/409/413/429/5xx/offline, polling with timeout, review draft building, save, add/remove line, 100-line cap, line error mapping); Drift DAO tests with an in-memory database; fake handler tests with contract fixtures for I1–I4; **widget tests for every screen in 4 states × 2 languages**, a dark smoke test per screen, RTL checks on review and list. All earlier tests stay green.

## 7. Checks you must pass before finishing
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```

## 8. Do not commit, push or merge.
Leave your changes in the working tree on `feature/scan-flow`. The orchestrator verifies and commits.

## 9. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <summary by folder>
Check outputs: <tails of each command in §7, with test counts>
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE   (anything else: stop before finishing and report it)
```
