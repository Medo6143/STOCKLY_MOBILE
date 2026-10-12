Read AGENTS.md fully before starting.

# Brief: mobile-2a-foundation

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/foundation` (already checked out) · Lane: MOBILE · Contract version: **v1.3** (`docs/api/contract.md`)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md, the design or the contract, **stop and report** instead of guessing.

## 1. Goal and why
`docs/design/frontend.md` (approved at checkpoint 2) is the binding design of the Flutter app. This brief builds its **foundation**, everything the screen briefs (2b splash + auth, 2c products, 2d invoices) will stand on, plus the fake backend core with the **auth** handlers only. When you finish, the app starts in fake mode, shows a placeholder home behind the auth redirect, and the core layers are fully tested. No feature screens yet.

## 2. Scope
**You may change / create:** the Flutter project at the repo root (`pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `l10n.yaml`, `lib/**`, `test/**`, `android/**`, `assets/fonts/**`), and `README.md` (run instructions only).

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/`, `docs/**` (except reading), `.gitignore`, `.editorconfig`, `.gitattributes`. No `git commit`, `push`, `merge`, `checkout`, `reset`, `stash`. The backend repository `D:\FLUTTER\stockly` is read-only.

**Machine safety:** never kill processes by image name (`taskkill /IM`, `pkill <name>`, `Stop-Process -Name`); stop only processes you started, by their PID. Never delete or change anything outside this repository, except the tool caches below.

**Environment (this machine; drive C: is small):** in every shell, before any `flutter`/`dart` command:
```bash
export PATH="/d/dev/flutter/bin:$PATH" PUB_CACHE='D:\dev\pub-cache' GRADLE_USER_HOME='D:\dev\gradle' ANDROID_USER_HOME='D:\dev\android-user' ANDROID_HOME='C:\Users\medow\AppData\Local\Android\Sdk' TEMP='D:\FLUTTER\_tmp' TMP='D:\FLUTTER\_tmp'
```
Flutter 3.47.7 stable, Dart 3.13.5. Target platform: **Android only** (`flutter create --platforms android`).

## 3. Critical rules for this task
Full rules: `AGENTS.md`. Copied here:
- 34. Every screen handles four states: loading, empty, error, data, using the shared `AsyncStateView`.
- 35. No hardcoded strings, colors, sizes or durations. Strings from ARB files, colors and spacing from theme tokens (`brand/` is the source).
- 36. Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`. Never `left`/`right`.
- 37. State is immutable (freezed). No business logic in widgets.
- 38. Tokens in `flutter_secure_storage` only. No API keys in the app, ever.
- 39. Respect "reduce motion": animations show their final frame.
- Layers: `presentation → domain → data`; widgets never import Dio or data-layer classes. Repositories return `Result<T, Failure>` (sealed), never throw to the UI.
- Shared: money and quantities are `Decimal` (never `double`), parsed from and sent as strings; the shop comes from the token, never from the app; switch on ProblemDetails `code`, never on `title`/`detail`; never log tokens or passwords; no dead code, no commented-out code, no TODO without an issue link; never weaken a test.
- **Packages**: only the stack in `AGENTS.md`. Add a package only when this brief's code uses it (no unused dependencies). Packages this brief needs: `flutter_riverpod`, `go_router`, `dio`, `freezed` + `freezed_annotation`, `json_serializable` + `json_annotation`, `build_runner`, `drift` + `drift_flutter` + `drift_dev`, `path_provider`, `flutter_secure_storage`, `decimal`, `intl` + `flutter_localizations`, `uuid`, `very_good_analysis`, `mocktail`. Use the latest stable versions that resolve with Flutter 3.47.7; commit nothing (the orchestrator commits `pubspec.lock`). **Any package not in `AGENTS.md`: stop and report.**
- Fonts: bundle the brand fonts (see `brand/stockly-brand.html`) from their official OFL sources under `assets/fonts/`, each with its `OFL.txt`. No `google_fonts` package.

## 4. Design sections you implement (binding: `docs/design/frontend.md`)
- §0 principles and §1 layers and folders (core part; feature folders only for `auth` data/domain needed by the session, and a placeholder home).
- §1.3 `Result`/`Failure` and the `ApiErrorCode` enum covering **every** code in contract §9 the app can receive, plus the `Http.*` codes.
- §2 Riverpod providers for the core (config, Dio, token storage, session/auth state, locale, theme, database, uuid, clock).
- §3 go_router skeleton with every route from §3 declared (screens not built yet show a localized placeholder) and the `authRedirect` table (§3.2) fully implemented and tested.
- §4 networking: `buildDio`, every interceptor in §4.1's order, `TokenStorage` (§4.3 single blob + installation id), `TokenRefresher` single-flight with the Drift lease and stale-token check, ProblemDetails → `Failure` mapping (§4.5, incl. `Retry-After` parsing), redacting log interceptor (§4.7).
- §5 decimal handling: wire parse/format with exact scales (money 2, quantity 3, factor 6, confidence 2), input parser (Arabic-Indic digits and separators), formatter (Western digits in both languages).
- §6 Drift database with **all 4 tables** of §6 (schema, indexes, DAOs needed by this brief: lease and preferences; queue/sales DAOs as schema plus minimal DAO used by tests), and migrations strategy (`schemaVersion` 1).
- §7 theme: `tokens.dart` (the only place with color literals) and every `ThemeExtension` (colors, spacing, radii, durations incl. `SplashTimings`, typography), light and dark, using the approved derived values.
- §8 l10n: `l10n.yaml`, `app_ar.arb` (template) and `app_en.arb` with every key needed here, **one message per error code** in both languages, RTL setup.
- §9 `AsyncStateView`, `EmptyState`, `ErrorState` (with retry and the error reference from §4.2).
- §12 fake backend **core** (`FakeBackendAdapter`, `FakeBackendState`, `FakeBackendConfig`, `BackendMode` const flag, release assert) and **only** `FakeAuthHandler` (A1–A5, rotation, token families: reusing a revoked refresh token revokes that login's whole family including its active token; other logins unaffected), with contract fixture tests for A1–A5 under `test/contract/`. No other handlers.
- `UuidGenerator` → `PackageUuidGenerator` over the `uuid` package (v4).
- §13 tests for these areas: decimal, error mapping, refresh queue, interceptors, router, storage, Drift (in-memory), architecture/imports, RTL ban, ARB parity, and widget tests for `AsyncStateView`/`EmptyState`/`ErrorState` in **4 states × 2 languages** (and dark smoke).

## 5. API contract (v1.3, binding sections)

### 1. Conventions

#### 1.1 Transport
- Base path: `/api`. HTTPS in production. JSON bodies use `Content-Type: application/json; charset=utf-8`, except the scan upload (`multipart/form-data`).
- JSON property names are **camelCase**. Unknown request properties are ignored. `null` and absent are equivalent for optional fields.
- Enum values are **PascalCase strings** (`"InvoiceReceipt"`, `"Owner"`), never numbers.

#### 1.2 Value formats

| Kind | JSON type | Format | Example |
|---|---|---|---|
| Id | string | UUID, lower-case, hyphenated | `"0192f0a0-6c1e-7b3a-9d2e-4f5a6b7c8d9e"` |
| Money (EGP) | **string** | exactly 2 decimals in responses; requests: up to 2 decimals, `>= 0` | `"125.50"` |
| Quantity (base or unit) | **string** | exactly 3 decimals in responses; requests: up to 3 decimals, sign allowed only where stated | `"1.500"`, `"-2.000"` |
| Unit factor | **string** | exactly 6 decimals in responses; requests: up to 6 decimals, `> 0` | `"3.000000"` |
| Match confidence | **string** | 2 decimals, `0.00`–`1.00` | `"0.85"` |
| Timestamp | string | ISO-8601 UTC with `Z`, up to microseconds | `"2026-10-12T07:00:00Z"` |
| Date | string | `yyyy-MM-dd` | `"2027-03-31"` |

- Money and quantities are **decimal strings** because Dart `double` cannot represent them exactly. The mobile app parses them with the `decimal` package. JSON numbers are rejected for these fields (`400 Validation.Failed`).
- Request decimal strings match `^-?\d{1,17}(\.\d+)?$`. More decimal places than allowed → `400 Precision.TooManyDecimals` (never rounded). Out of the column range → `400 Precision.OutOfRange`.

#### 1.3 Paging
- Query: `page` (int, default `1`, `>= 1`), `pageSize` (int, default `20`, `1..100`). `pageSize > 100` → `400 Validation.Failed` (never silently clamped, AGENTS.md rule 30).
- Response:

```json
{ "items": [ ], "page": 1, "pageSize": 20, "totalCount": 137 }
```

#### 1.4 Authentication
- `Authorization: Bearer <accessToken>` on every endpoint except register, login and refresh.
- **Access token**: JWT, lifetime **15 minutes**. Claims: `sub` (user id), `shop_id` (active shop), `role` (`Owner` | `Staff`). The shop comes only from the token, never from a request (ADR-0002).
- **Refresh token**: opaque random string, lifetime **30 days**, stored hashed. Every refresh **rotates** it (the old one is revoked). Presenting a revoked refresh token **revokes the whole chain** and returns `401 Auth.RefreshTokenReused` (AGENTS.md rule 13).
- **Client rule:** on `401` from any authenticated endpoint, the client calls `POST /api/auth/refresh` **once**, then retries the original request **once**. Concurrent `401`s share one refresh (request queue). If the refresh fails, the client signs out.
- Roles: `user` = Owner or Staff of the active shop. `owner` = Owner only. A Staff user calling an owner-only endpoint gets `403 Auth.Forbidden`.
- A suspended shop (`ShopStatus.Suspended`) gets `403 Shop.Suspended` on login, refresh and every authenticated call except logout (A4), so the user can always sign out.

#### 1.5 Localization
- `Accept-Language: ar` or `en` (default `ar`). It selects the language of ProblemDetails `title`/`detail` and validation messages. Codes never change with the language.
- Product and shop names are returned exactly as stored.

#### 1.6 Idempotency
- `POST /api/invoices/scan` and `POST /api/sales` require a client-generated `clientRequestId` (UUID, created once per scan/sale and reused on every retry). A repeat with the same `clientRequestId` in the same shop returns the **existing** resource with `200` instead of creating a new one (ADR-0006).
- `POST /api/invoices/{id}/confirm` is idempotent: confirming a confirmed invoice returns `200` with the confirmed invoice and changes nothing.

#### 1.7 Correlation and tracing
- Optional request header `X-Correlation-Id` (1–64 chars of `[A-Za-z0-9._-]`); otherwise the server creates one. It is always echoed in the response header and in ProblemDetails.

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

---

### 2. Endpoint index (rows for this brief)

| # | Method | Path | Auth | Statuses | Step | State |
|---|---|---|---|---|---|---|
| A1 | POST | /api/auth/register | anonymous | 201, 400, 409 | 1.5 | planned |
| A2 | POST | /api/auth/login | anonymous | 200, 400, 401, 403 | 1.5 | planned |
| A3 | POST | /api/auth/refresh | anonymous | 200, 400, 401, 403 | 1.5 | planned |
| A4 | POST | /api/auth/logout | user | 204, 400, 401 | 1.5 | planned |
| A5 | GET | /api/auth/me | user | 200, 401, 403 | 1.5 | planned |

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

Responses: `201` `AuthResponse` (role `Owner`). `400 Validation.Failed`, `400 Shop.NameRequired`. `409 Auth.EmailTaken`.

#### A2 `POST /api/auth/login` (anonymous)
Request: `{ "email": string, "password": string, "deviceId": string|null }`

Responses: `200` `AuthResponse`. `401 Auth.InvalidCredentials` (same code for unknown email and wrong password). `403 Shop.Suspended`. `403 Auth.NoActiveShop` (user has no active membership).
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

### 9. Error code catalogue

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
| `Shop.NameRequired` | 400 | A1 | Shop name blank after normalization |
| `Shop.UnknownType` | 400 | A1 | Unsupported shop type |
| `Shop.Suspended` | 403 | all authenticated, A2, A3 | Shop suspended by the platform admin |
| `Product.NotFound` | 404 | P2–P12, I4, S1 | No such product in this shop |
| `Product.NameRequired` | 400 | P3, P4 | Name blank after normalization |
| `Product.Archived` | 409 | P4, P6–P8 | Archived products cannot be edited |
| `Product.DuplicateBarcode` | 409 | P3, P4 | Barcode used by another active product |
| `Product.OpeningStockOwnerOnly` | 403 | P3 | Only the Owner may set `openingQuantity` |
| `ProductUnit.NotFound` | 404 | P7–P10, I4, S1 | No such unit on this product |
| `ProductUnit.NameRequired` | 400 | P3, P6, P7 | Unit name blank |
| `ProductUnit.DuplicateName` | 409 | P6, P7 | Unit name already used on the product |
| `ProductUnit.DuplicateBarcode` | 409 | P6, P7 | Unit barcode already used in the shop |
| `ProductUnit.BaseUnitCannotBeRemoved` | 400 | P8 | |
| `ProductUnit.BaseUnitFactorFixed` | 400 | P7 | Base unit factor is always 1 |
| `ProductUnit.InUse` | 409 | P8 | Unit referenced by invoice or sale lines |
| `Precision.TooManyDecimals` | 400 | money/quantity/factor inputs | |
| `Precision.Negative` | 400 | money, threshold, count | |
| `Precision.NotPositive` | 400 | factor | |
| `Precision.OutOfRange` | 400 | money/quantity/factor inputs | Value does not fit the column |
| `Stock.ZeroChange` | 400 | P9 | |
| `Stock.NoteRequired` | 400 | P9 | |
| `Invoice.NotFound` | 404 | I3–I5 | |
| `Invoice.ImageRequired` | 400 | I1 | |
| `Invoice.UnsupportedImageType` | 400 | I1 | |
| `Invoice.ImageTooLarge` | 413 | I1 | Over 8 MB |
| `Invoice.NotEditable` | 409 | I4 | Not in NeedsReview |
| `Invoice.NotConfirmable` | 409 | I5 | Processing or Failed |
| `Invoice.LineProductRequired` | 400 | I4, I5 | Line has neither product nor newProduct |
| `Invoice.UnitNotOfProduct` | 400 | I4 | Unit belongs to another product |
| `Scan.RateLimited` | 429 | I1 | Per-minute limit; `Retry-After` header |
| `Scan.DailyQuotaExceeded` | 429 | I1 | Plan's daily scan quota used up; `Retry-After` = seconds until Cairo midnight (v1.3) |
| `Sale.NotFound` | 404 | S3 | |
| `Sale.ArchivedProduct` | 400 | S1 | Archived products cannot be sold |
| `Sale.UnitNotOfProduct` | 400 | S1 | Unit belongs to another product |
| `Stock.NegativeBalance` | — | S1 warnings | Not an error: sale succeeded, stock is negative |

Domain movement-rule codes (`Stock.InvoiceSourceRequired`, `Stock.SaleSourceRequired`, `Stock.SourceNotAllowed`, `Stock.EmptySourceReference`, `Stock.ChangeMustBePositive`, `Stock.ChangeMustBeNegative`, `Stock.UserRequired`, `Stock.UnknownReason`) protect server-built movements; a client request cannot trigger them. If one ever reaches the API it is a server bug and is returned as `500 Server.Unexpected`.

---


## 6. Checks you must pass before finishing
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```
Zero analyzer issues (very_good_analysis), zero test failures, formatting clean, debug APK builds. Never skip, delete or weaken a test.

## 7. Do not commit, push or merge.
Leave your changes in the working tree on `feature/foundation`. The orchestrator verifies and commits.

## 8. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <summary by folder, plus pubspec dependencies with versions>
Check outputs: <tails of each command in §6, with test counts>
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE   (anything else: stop before finishing and report it)
```
