Read AGENTS.md fully before starting.

# Brief: mobile-7-plans-payments

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/plans-payments` (already checked out, based on `main`) · Lane: MOBILE · Contract version: **v1.7** (`docs/api/contract.md` §12)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md, the design or the contract, **stop and report** instead of guessing.

## 1. Goal and why
The product owner wants shop owners to see their plan and its limits, and to pay for a better plan by **card (Visa/Mastercard/Meeza), Vodafone Cash or other wallets, or cash at a kiosk**, through Paymob (hosted checkout). The backend is building B1–B6 now with exactly this contract. Build the screens, the data layer, the fake backend handlers and the tests, in the app's modern design.

## 2. Scope
**You may change / create:** `lib/**`, `test/**`, `pubspec.yaml`/`pubspec.lock` (**only** `url_launcher`, approved for this brief, to open the Paymob hosted checkout in the system browser / Custom Tab), `android/app/src/main/AndroidManifest.xml` (only the `<queries>` entry `url_launcher` needs for https), `README.md` (screens and run sections).

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/**`, `docs/**`, `android/app/src/debug/**`, `android/app/build.gradle.kts`, `.github/**`.

**Git and machine safety:** never run git commands that change the working tree or history (`checkout`, `reset`, `stash`, `commit`, `merge`, `push`); edit files back instead. Never kill processes by image name. **Do not start the emulator and do not install or launch the app.** Never change anything outside this repository except the tool caches.

**Environment:** in every shell, before any `flutter`/`dart` command:
```bash
export PATH="/d/dev/flutter/bin:$PATH" PUB_CACHE='D:\dev\pub-cache' GRADLE_USER_HOME='D:\dev\gradle' ANDROID_USER_HOME='D:\dev\android-user' ANDROID_HOME='D:\Android\Sdk' TEMP='D:\FLUTTER\_tmp' TMP='D:\FLUTTER\_tmp'
```

## 3. What to build (binding)
New feature `billing` (domain, data, presentation), same layering and patterns as the other features.
- **Profile:** a "Your plan" card under the shop card: plan name, price per month (or "Free"), "{used} of {quota} scans today" with a progress bar, members "{n} of {max}", renewal/end date when present, and a pending-payment banner if `pendingPayment` is set. Tapping opens the plans screen.
- **Dashboard:** when `scansToday >= 80 %` of the quota, a soft warning card with "Upgrade" (Owner only).
- **PlansScreen** (`/profile/plans`): B1 list as cards (current plan marked, price, quota, members). Owner sees "Choose" on paid plans that are not current; Staff sees the plans read-only with a note to ask the owner. Free plans have no button.
- **CheckoutSheet** (Owner): method picker (Card · Vodafone Cash / wallet · Kiosk cash), with icons and short explanations; wallet asks for the phone (`^01[0125][0-9]{8}$`, Arabic-Indic digits accepted and normalised); amount shown read-only from the plan. Submit → B3 with a `clientRequestId` generated once per attempt (UuidGenerator) and reused on retry (rule 20).
  - Card/Wallet → open `checkoutUrl` with `url_launcher` in `LaunchMode.externalApplication` (or in-app browser view / Custom Tab), then show **PaymentStatusScreen**.
  - Kiosk → **PaymentStatusScreen** showing the reference number large (copy button, LtrIsolate), amount, expiry, and steps "pay this reference in cash at any kiosk partner".
- **PaymentStatusScreen** (`/profile/payments/:id`): polls B4 every 3 s while visible and `Pending` (cancellable timer, stops on dispose; also refresh on app resume) up to the payment's `expiresAt`; `Paid` → success check animation and invalidate subscription/dashboard; `Failed`/`Expired` → message (`failureReason` shown as secondary text only) and "Try again" (new `clientRequestId`); "Cancel payment" (B6, Owner) while Pending. The redirect back from the browser never decides anything: only B4's status does.
- **PaymentHistoryScreen** (`/profile/payments`): B5 paged list with status pills.
- Error codes (switch on `code` only): `Billing.FreePlan`, `Billing.MethodUnavailable` ("This payment method isn't available yet"), `Billing.PaymentPending` (offer to open the pending payment), `Billing.NotCancelable`, `Billing.ProviderUnavailable` (retry safe), `Plan.NotFound`, `Plan.Inactive`, `Payment.NotFound`, `Auth.Forbidden`, `Validation.Failed` (wallet phone under the field).
- **Fake backend:** `FakeBillingHandler` for B1–B6 with the contract's validation and idempotency, two seeded paid plans plus the free one, a fake hosted checkout URL (`https://fake.stockly.invalid/pay/{id}` — the fake must not try to open it; in fake mode the status screen offers a debug-panel action "Simulate payment success / failure" so QA can finish the flow), kiosk reference generation, and transition of Pending→Paid/Failed driven by the debug panel or by expiry on the fake clock. Contract fixture tests for B1–B6 under `test/contract/`.
- Extend `test/live/live_api_test.dart` (tag `live`): B1 and B2 only (no real payment can be made in tests); B3 must not be called in the live test.

## 4. Critical rules
34 (4 states on every screen), 35 (no hardcoded strings/colors/sizes/durations; ARB ar template + en), 36 (directional), 37 (freezed state, no logic in widgets), 38 (no keys in the app; the app never sees Paymob keys), 39 (reduce motion). Money as `Money`/`Decimal` strings, never `double`. Owner-only actions hidden for Staff and `403` still handled.

## 5. Tests
Use cases and notifiers (checkout per method, idempotent retry keeps the id, new attempt gets a new id, polling stops on terminal status and on dispose, resume refresh), wallet phone rules, fake handler with fixtures, widget tests for every new screen and the profile/dashboard cards in 4 states × ar/en, dark smoke, RTL, Staff vs Owner visibility, reduce motion. A fake `UrlLauncher` interface in tests (wrap `url_launcher` behind `ExternalBrowser` in core so presentation never imports the package).

## 6. Checks
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test --exclude-tags live
dart run tool/coverage_gate.dart        # after flutter test --coverage --exclude-tags live
dart format --set-exit-if-changed lib test tool
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```

## 7. Do not commit, push or merge.

## 8. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <summary by folder>
Check outputs: <tails of each command, with test counts and coverage %>
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE
```
