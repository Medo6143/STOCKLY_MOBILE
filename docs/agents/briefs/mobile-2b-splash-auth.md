Read AGENTS.md fully before starting.

# Brief: mobile-2b-splash-auth

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/splash-auth` (already checked out) · Lane: MOBILE · Contract version: **v1.4** (`docs/api/contract.md`)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md, the design or the contract, **stop and report** instead of guessing.

## 1. Goal and why
Foundation 2a is merged: core layers, theme, l10n, router with `authRedirect`, Dio + refresh, Drift, `AsyncStateView`, fake backend core with auth handlers A1–A5 (read `docs/sprints/log.md` and the code). Now build the first real screens so a user can start the app, see the brand splash, register, log in, get blocked when the shop is suspended, and change language/theme or sign out. Build against the **fake backend**; everything must also work unchanged against the real API (contract v1.4).

## 2. Scope
**You may change / create:** `lib/**`, `test/**`, `assets/splash/**`, `pubspec.yaml`, `pubspec.lock`, `flutter_native_splash.yaml` (repo root), `android/**` (only what `flutter_native_splash` generates), `README.md` (run section).

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/**` (read only), `docs/**` (read only), `.gitignore`, `.editorconfig`, `.gitattributes`.

**Git and machine safety:** never run git commands that change the working tree or history (`checkout`, `reset`, `stash`, `commit`, `merge`, `push`); to undo your own edit, edit the file back. Never kill processes by image name; stop only processes you started, by PID. Never change anything outside this repository except the tool caches below.

**Environment:** in every shell, before any `flutter`/`dart` command:
```bash
export PATH="/d/dev/flutter/bin:$PATH" PUB_CACHE='D:\dev\pub-cache' GRADLE_USER_HOME='D:\dev\gradle' ANDROID_USER_HOME='D:\dev\android-user' ANDROID_HOME='D:\Android\Sdk' ANDROID_AVD_HOME='C:\Users\medow\.android\avd' TEMP='D:\FLUTTER\_tmp' TMP='D:\FLUTTER\_tmp'
```
The emulator `QA_Pixel_7` (`emulator-5554`) may be running; you may install and launch your debug APK on it to check the screens, but do not create, delete or modify AVDs.

## 3. Critical rules for this task
Full rules: `AGENTS.md`. Copied here:
- 34. Every screen handles loading, empty, error, data with `AsyncStateView`.
- 35. No hardcoded strings, colors, sizes or durations (ARB files, theme tokens; `SplashTimings` for the animation).
- 36. Directional APIs only (`EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`).
- 37. Immutable freezed state; no business logic in widgets.
- 38. Tokens only in secure storage; no API keys.
- 39. Reduce motion: the animated splash shows its final frame immediately.
- Layers: presentation never imports Dio, Drift or data classes; repositories return `Result<T, Failure>`.
- Shared: switch on `code`, never on `title`/`detail`; never log tokens or passwords; no dead code; never weaken a test.
- **Packages:** only the stack in `AGENTS.md`. This brief adds `flutter_animate` and `flutter_native_splash` (dev/config). Any other package: stop and report. **PNG exports** of the splash images are produced with a command-line rasterizer that is **not** an app dependency: use the installed headless Chrome (`C:\Program Files\Google\Chrome\Application\chrome.exe --headless --screenshot ...`) on a small local HTML/SVG file you create under `D:\FLUTTER\_tmp`; do not download tools. Keep the derived outline-only SVG next to the PNGs in `assets/splash/`.

## 4. Design sections you implement (binding: `docs/design/frontend.md`, approved; decisions in §15.1)
- §10 Splash: native splash (`flutter_native_splash`, light/dark, Android 12) showing **only the receipt outline with full-width lines and no pixels** (§15.1 decision 6), then the animated splash with the exact `SplashTimings` from the brand (`brand/stockly-brand.html`), reduce-motion behaviour (§10.4), `FlutterNativeSplash.preserve()/remove()` handoff.
- **Splash minimum fix:** `authRedirect` currently sends a resolved signed-out user from `/splash` to `/login` immediately, bypassing the splash minimum. Add a "splash finished" input (min/max timing from `SplashTimings`) so the redirect leaves `/splash` only after the minimum, and test the redirect table again (§3.2) including this row.
- §11 Sprint 3 screens: `SplashScreen`, `LoginScreen`, `RegisterScreen`, `ShopSuspendedScreen`, `SettingsScreen` (language `system`/`ar`/`en`, theme `system`/`light`/`dark`, shop name/type/role, sign out, app version), with their four states exactly as §11 lists.
- §12 debug `FakeBackendPanel`: fake mode only, opened by **long-pressing the version text in Settings**: toggle offline, force the next request to fail with a chosen `ApiErrorCode`, expire the access token now, suspend the shop, and the lockout/rate-limit switches below.
- **Contract v1.4 additions** (new since 2a):
  - Add `Auth.LockedOut` (423) and `Auth.TooManyRequests` (429) to `ApiErrorCode`, the `Failure` mapping (with `retryAfter` from the `Retry-After` header) and the ARB files (ar + en). The login screen shows the lockout message with the remaining minutes (from `retryAfter`) and keeps the form usable; 429 shows "too many attempts, try again in N seconds" and disables submit until `Retry-After` elapses.
  - `FakeAuthHandler`: 5 wrong passwords lock the account for 15 minutes (423 with `Retry-After`, even with the correct password; success resets the count; unknown emails never lock), and 10 login or register requests per minute → 429 with `Retry-After` (configurable in `FakeBackendConfig`, switchable in the panel). Contract fixture tests for these responses.
- Seed (fake backend): keep the Owner and Staff users from 2a and **document their emails and passwords** in `README.md` under "Run in fake mode", together with the run command and how to open the debug panel.

## 5. API contract (v1.4, binding sections)

#### 1.4 Authentication
- `Authorization: Bearer <accessToken>` on every endpoint except register, login and refresh.
- **Access token**: JWT, lifetime **15 minutes**. Claims: `sub` (user id), `shop_id` (active shop), `role` (`Owner` | `Staff`). The shop comes only from the token, never from a request (ADR-0002).
- **Refresh token**: opaque random string, lifetime **30 days**, stored hashed. Every refresh **rotates** it (the old one is revoked). Presenting a revoked refresh token **revokes the whole chain** and returns `401 Auth.RefreshTokenReused` (AGENTS.md rule 13).
- **Client rule:** on `401` from any authenticated endpoint, the client calls `POST /api/auth/refresh` **once**, then retries the original request **once**. Concurrent `401`s share one refresh (request queue). If the refresh fails, the client signs out.
- Roles: `user` = Owner or Staff of the active shop. `owner` = Owner only. A Staff user calling an owner-only endpoint gets `403 Auth.Forbidden`.
- **Account lockout (v1.4):** 5 failed logins in a row on an existing account lock it for **15 minutes**. While locked, login returns `423 Auth.LockedOut` with `Retry-After` (whole seconds until the lockout ends, at least 1), **even with the correct password**. A successful login resets the failure count.
- **Rate limiting (v1.4):** `POST /api/auth/login` and `POST /api/auth/register` each allow **10 requests per minute per client IP** (fixed window). The 11th returns `429 Auth.TooManyRequests` with `Retry-After` (seconds until the window resets). The client shows the message and does not retry automatically before `Retry-After`.
- A suspended shop (`ShopStatus.Suspended`) gets `403 Shop.Suspended` on login, refresh and every authenticated call except logout (A4), so the user can always sign out.

#### 1.5 Localization
- `Accept-Language: ar` or `en` (default `ar`). It selects the language of ProblemDetails `title`/`detail` and validation messages. Codes never change with the language.
- Product and shop names are returned exactly as stored.

#### 1.8 Errors (RFC 7807)
Every error response is `application/problem+json`:

```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.10",
  "title": "Conflict",
  "status": 409,
  "detail": "This product already has a unit with this name.",
  "instance": "POST /api/products/0192.../units",
  "code": "ProductUnit.DuplicateName",
  "traceId": "00-...-...-00",
  "correlationId": "abc-123"
}
```

- `code` is always present and stable; clients switch on `code`, never on `title`/`detail`.
- Request-shape validation (FluentValidation) returns `400` with `code: "Validation.Failed"` and `errors`: `{ "<camelCaseField>": ["<localized message>"] }`. Nested fields use dots and indexes: `"items[2].quantity"`.
- Mapping from `ErrorType`: Validation → 400, Unauthorized → 401, Forbidden → 403, NotFound → 404, Conflict → 409, Failure → 500.
- **Wrong tenant is 404**, with the resource's `NotFound` code (AGENTS.md rule 10).
- Unexpected server errors: `500`, `code: "Server.Unexpected"`, no exception details.
- Errors raised by the framework before any handler runs carry an `Http.*` code: `404 Http.NotFound` (unknown route), `405 Http.MethodNotAllowed`, `415 Http.UnsupportedMediaType`. They are not repeated per endpoint.
- Error codes that can occur on **every** authenticated endpoint are not repeated per endpoint: `401 Auth.Unauthenticated`, `403 Shop.Suspended`, `400 Validation.Failed`, `500 Server.Unexpected`.

### 2. Endpoint index (rows for this brief)

| # | Method | Path | Auth | Statuses | Step | State |
|---|---|---|---|---|---|---|
| A1 | POST | /api/auth/register | anonymous | 201, 400, 409, 429 | 1.5 | implemented |
| A2 | POST | /api/auth/login | anonymous | 200, 400, 401, 403, 423, 429 | 1.5 | implemented |
| A3 | POST | /api/auth/refresh | anonymous | 200, 400, 401, 403 | 1.5 | implemented |
| A4 | POST | /api/auth/logout | user | 204, 400, 401 | 1.5 | implemented |
| A5 | GET | /api/auth/me | user | 200, 401, 403 | 1.5 | implemented |

### 3. Shared schemas

```text
AuthResponse {
  accessToken: string                 // JWT
  accessTokenExpiresAt: timestamp
  refreshToken: string                // opaque; store in secure storage only
  refreshTokenExpiresAt: timestamp
  user: UserDto
  shop: ShopMembershipDto             // the active shop of this token
}

UserDto { id: uuid, email: string, fullName: string, phone: string|null, preferredLanguage: "ar"|"en" }

ShopMembershipDto {
  id: uuid, name: string,
  shopType: "Pharmacy"|"Grocery"|"MobileShop"|"Other",
  status: "Active"|"Suspended",
  role: "Owner"|"Staff"
}

UnitDto {
  id: uuid, name: string,
  factor: factor-string,              // base units in one of this unit; "1.000000" for the base unit
  sellPrice: money-string,
  barcode: string|null,
  isBase: boolean
}

ProductListItem {
  id: uuid, name: string,
  quantity: quantity-string,          // base unit; may be negative
  baseUnit: { id: uuid, name: string, sellPrice: money-string },
  lowStockThreshold: quantity-string,
  isLowStock: boolean,                // quantity <= lowStockThreshold
  isArchived: boolean
}

ProductDetail {
  id: uuid, name: string,
  barcode: string|null, category: string|null,
  quantity: quantity-string, costPrice: money-string,   // cost per base unit
  lowStockThreshold: quantity-string, isLowStock: boolean, isArchived: boolean,
  units: UnitDto[],                   // base unit first, then by factor ascending
  createdAt: timestamp, updatedAt: timestamp
}

StockMovementDto {
  id: uuid, productId: uuid,
  quantityChange: quantity-string,    // base unit, never "0.000"
  balanceAfter: quantity-string,
  reason: "InvoiceReceipt"|"Sale"|"ManualAdjustment"|"StockCount"|"InvoiceReversal",
  invoiceId: uuid|null, saleId: uuid|null,
  note: string|null,
  createdByUserId: uuid,
  createdAt: timestamp
}
```

---

### 4. Auth (step 1.5)

#### A1 `POST /api/auth/register` (anonymous)
Creates the user, the shop, the Owner membership and the active subscription to the default plan, in one transaction.

Request:
```json
{
  "fullName": "Mona Adel",
  "email": "mona@example.com",
  "password": "Str0ngPass",
  "phone": "01001234567",
  "preferredLanguage": "ar",
  "deviceId": "pixel-7-abc",
  "shop": { "name": "صيدلية الشفاء", "shopType": "Pharmacy", "phone": null, "governorate": "القاهرة", "address": null }
}
```
- `email`: required, valid, max 256, case-insensitive unique. `password`: required, 8–128 chars, at least one letter and one digit. `fullName`: required, max 200. `phone`: optional, max 30. `preferredLanguage`: optional, `ar` (default) or `en`. `deviceId`: optional, max 100. `shop.name`: required, max 200, non-empty after Arabic normalization. `shop.shopType`: required.

Responses: `201` `AuthResponse` (role `Owner`). `400 Validation.Failed`, `400 Shop.NameRequired`. `409 Auth.EmailTaken`. `429 Auth.TooManyRequests` (v1.4, `Retry-After`).

#### A2 `POST /api/auth/login` (anonymous)
Request: `{ "email": string, "password": string, "deviceId": string|null }`

Responses: `200` `AuthResponse`. `401 Auth.InvalidCredentials` (same code for unknown email and wrong password). `403 Shop.Suspended`. `403 Auth.NoActiveShop` (user has no active membership). `423 Auth.LockedOut` (v1.4, `Retry-After`; checked before the password). `429 Auth.TooManyRequests` (v1.4, `Retry-After`).
If the user belongs to several shops, the token is for the active membership joined first; switching shops is not in v1.

#### A3 `POST /api/auth/refresh` (anonymous)
Request: `{ "refreshToken": string }` → `200` `AuthResponse` with a **new** refresh token (the old one is revoked).
Errors: `401 Auth.InvalidRefreshToken` (unknown or expired), `401 Auth.RefreshTokenReused` (revoked token presented: the whole chain is revoked), `403 Shop.Suspended`.

#### A4 `POST /api/auth/logout` (user)
Request: `{ "refreshToken": string }` → `204`. Revokes that refresh token and its chain. Works for suspended shops too (no 403). Unknown or already revoked token → still `204` (logout is idempotent). `400 Validation.Failed` when the field is missing.

#### A5 `GET /api/auth/me` (user)
Used at app start-up to restore the session.
`200` `{ "user": UserDto, "shop": ShopMembershipDto }`: the user (including `preferredLanguage`), the active shop of the token and the user's `role` in it.

---

### 9. Error codes for this brief

| Code | Status | Where | Meaning |
|---|---|---|---|
| `Validation.Failed` | 400 | all | Request shape or format invalid; see `errors` |
| `Server.Unexpected` | 500 | all | Unexpected error; no details |
| `Http.NotFound` | 404 | framework | Unknown route |
| `Http.MethodNotAllowed` | 405 | framework | Route exists, method does not |
| `Http.UnsupportedMediaType` | 415 | framework | Wrong `Content-Type` |
| `Auth.Unauthenticated` | 401 | all authenticated | Missing, invalid or expired access token |
| `Auth.Forbidden` | 403 | owner-only | Role not allowed |
| `Auth.EmailTaken` | 409 | A1 | Email already registered |
| `Auth.InvalidCredentials` | 401 | A2 | Unknown email or wrong password |
| `Auth.NoActiveShop` | 403 | A2 | User has no active shop membership |
| `Auth.InvalidRefreshToken` | 401 | A3 | Unknown or expired refresh token |
| `Auth.RefreshTokenReused` | 401 | A3 | Revoked token reused; chain revoked |
| `Auth.LockedOut` | 423 | A2 | Too many failed logins; locked for 15 minutes; `Retry-After` (v1.4) |
| `Auth.TooManyRequests` | 429 | A1, A2 | More than 10 requests per minute from this IP; `Retry-After` (v1.4) |
| `Shop.NameRequired` | 400 | A1 | Shop name blank after normalization |
| `Shop.UnknownType` | 400 | A1 | Unsupported shop type |
| `Shop.Suspended` | 403 | all authenticated, A2, A3 | Shop suspended by the platform admin |

### 10. Decisions 6–8, 18–19

6. Login with several memberships picks the active membership joined first; no shop switching in v1.
7. Logout is idempotent (204 even for an unknown token).
8. `GET /api/auth/me` added for app start-up.
18. (v1.4) Lockout uses ASP.NET Core Identity lockout: 5 consecutive failures → 15 minutes, for every account. It applies to existing accounts only; an unknown email keeps returning `401 Auth.InvalidCredentials`. This lets a caller who fails 5 times on one email learn that the account exists; the per-IP rate limit bounds how fast that can be probed. Accepted trade-off.
19. (v1.4) Rate limits are per endpoint and per client IP (`HttpContext.Connection.RemoteIpAddress`), fixed 60-second window, built-in ASP.NET Core rate limiter. Behind a reverse proxy, forwarded headers must be configured at deployment so the client IP is used (release sprint).


## 6. Tests
Per §13: unit tests for every new notifier/use case (login, register, logout, settings, splash min/max timing, lockout countdown), the redirect table, the fake auth handler (lockout, rate limit) with contract fixtures, and **widget tests for every screen above in 4 states × 2 languages** (`ar`, `en`), a dark smoke test per screen, RTL assertions on login/register, and the reduce-motion splash test. All 2a tests stay green.

## 7. Checks you must pass before finishing
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
dart run flutter_native_splash:create
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```
Zero analyzer issues, zero failures, formatting clean, APK builds. Never skip, delete or weaken a test.

## 8. Do not commit, push or merge.
Leave your changes in the working tree on `feature/splash-auth`. The orchestrator verifies and commits.

## 9. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <summary by folder; pubspec changes with versions>
Check outputs: <tails of each command in §7, with test counts>
Seed credentials and debug panel: <exactly as documented in README>
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE   (anything else: stop before finishing and report it)
```
