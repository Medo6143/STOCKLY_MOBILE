Read AGENTS.md fully before starting.

# Brief: mobile-4-confirm-sales-dashboard

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/sprint-4` (already checked out, based on `main` with the scan flow merged) · Lane: MOBILE · Contract version: **v1.4** (`docs/api/contract.md`)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md, the design or the contract, **stop and report** instead of guessing.

## 1. Goal and why
Sprint 4 on mobile: the owner confirms a reviewed invoice (stock goes up), records quick sales by barcode or search (stock goes down, works offline through the pending-sales queue), and sees a dashboard with low stock, negative stock, expiring items and today's sales. The backend is building I5, S1–S3, P12 and D1–D2 with exactly this contract; the app must work unchanged against it.

## 2. Scope
**You may change / create:** `lib/**`, `test/**`, `pubspec.yaml`/`pubspec.lock` (only packages approved in `docs/design/frontend.md` §14; `mobile_scanner` is approved for Sprint 4), `README.md` (run section only), `android/app/src/main/AndroidManifest.xml` only for what `mobile_scanner` needs.

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/**`, `docs/**` (read only), `android/app/src/debug/**`, `.gitignore`, `.editorconfig`, `.gitattributes`.

**Git and machine safety:** never run git commands that change the working tree or history (`checkout`, `reset`, `stash`, `commit`, `merge`, `push`). To undo your own edit, edit the file back. Never kill processes by image name; stop only processes you started, by PID. **Do not start the Android emulator and do not install or launch the app.** Never change anything outside this repository except the tool caches below.

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
- 39. Reduce motion respected.
- Layers: presentation never imports Dio, Drift or data classes; repositories return `Result<T, Failure>`.
- Shared: money/quantity values are `Decimal` sent as strings with contract scales; switch on `code` only; no dead code; never weaken a test.
- Rule 20 / ADR-0006: every sale has a `clientRequestId` stored with the pending sale **before** the first send and reused on every retry; confirm is idempotent, so retrying it is safe.

## 4. Design sections you implement (binding: `docs/design/frontend.md`)
- §11 **Sprint 4** table exactly: confirm on `InvoiceReviewScreen` (save if dirty first, then I5; invalidate products and dashboard), `DashboardScreen` (becomes the home after login), `ExpiringSoonScreen`, low-stock entry, `QuickSaleScreen` with the "Quick sale cart rules" under the table, `SaleListScreen`, `SaleDetailScreen`.
- §6.8 pending sales (Drift) with the locked "unknown outcome" cart and Retry.
- `BarcodeScanner` behind the interface with `mobile_scanner`, plus the keyboard-wedge text field (submit on Enter).
- Wire P12 (already in the products data layer) into the quick-sale screen.
- §12 fake backend: handlers for I5, S1–S3, D1–D2, extending the existing fake products/invoices state (confirm receives stock with movements and new products; sales take stock out with negative warnings; dashboard computed from fake state with the Cairo day). Contract fixture tests under `test/contract/` for each.
- Extend `test/live/live_api_test.dart` (tag `live`, excluded by default) with: create a sale for the product created earlier (repeat with the same `clientRequestId` returns `200` and the same id), S2 list, S3 detail, D1 summary, D2 expiring soon, P12 lookup by the product barcode.

## 5. Tests
Unit tests for every use case and notifier (cart rules, override, 100-line cap, duplicate barcode scan adds 1, pending-sale state machine incl. unknown outcome, confirm flow incl. dirty save first); Drift DAO tests; fake handler tests with fixtures; **widget tests for every new screen in 4 states × 2 languages**, dark smoke test per screen, RTL checks on quick sale and dashboard. All earlier tests stay green.

## 6. Checks you must pass before finishing
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```

## 7. Do not commit, push or merge.
Leave your changes in the working tree on `feature/sprint-4`. The orchestrator verifies and commits.

## 8. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <summary by folder>
Check outputs: <tails of each command in §6, with test counts>
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE   (anything else: stop before finishing and report it)
```
