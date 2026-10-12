Read AGENTS.md fully before starting.

# Brief: mobile-2c-products

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/products` (already checked out) · Lane: MOBILE · Contract version: **v1.4** (`docs/api/contract.md`)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md, the design or the contract, **stop and report** instead of guessing.

## 1. Goal and why
Foundation (2a) and splash/auth (2b) are merged (see `docs/sprints/log.md`). Now the product catalog: a shop owner browses, searches and filters products, creates them (Owner may set opening stock), edits them, manages units, adjusts stock, records counts and reads the movement history, in Arabic and English. Build against the fake backend, adding **only** the fake handlers for P1–P12, with contract fixture tests. The same code must work unchanged against the real API (backend step 1.6 implements P1–P11 with exactly this contract).

## 2. Scope
**You may change / create:** `lib/**`, `test/**`, `pubspec.yaml`/`pubspec.lock` (only if a package from `AGENTS.md` is needed), `README.md` (run section only).

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/**`, `docs/**` (read only), `android/**`, `.gitignore`, `.editorconfig`, `.gitattributes`.

**Git and machine safety:** never run git commands that change the working tree or history (`checkout`, `reset`, `stash`, `commit`, `merge`, `push`); to undo your own edit, edit the file back. Never kill processes by image name; stop only processes you started, by PID. Never change anything outside this repository except the tool caches below.

**Environment:** in every shell, before any `flutter`/`dart` command:
```bash
export PATH="/d/dev/flutter/bin:$PATH" PUB_CACHE='D:\dev\pub-cache' GRADLE_USER_HOME='D:\dev\gradle' ANDROID_USER_HOME='D:\dev\android-user' ANDROID_HOME='D:\Android\Sdk' ANDROID_AVD_HOME='C:\Users\medow\.android\avd' TEMP='D:\FLUTTER\_tmp' TMP='D:\FLUTTER\_tmp'
```

## 3. Critical rules for this task
Full rules: `AGENTS.md`. Copied here:
- 34. Every screen: loading, empty, error, data with `AsyncStateView`.
- 35. No hardcoded strings, colors, sizes or durations.
- 36. Directional APIs only.
- 37. Immutable freezed state; no business logic in widgets.
- Layers: presentation never imports Dio, Drift or data classes; repositories return `Result<T, Failure>`.
- Shared: money, quantities and factors are `Decimal` parsed from and sent as **strings** with the contract's scales (money 2, quantity 3, factor 6), never `double`; switch on `code`; the shop comes from the token; no dead code; never weaken a test.
- Owner-only actions (archive, adjust, stock count, opening quantity) are hidden or disabled for Staff (from the session role), and a `403` is still handled if it happens.
- **Packages:** none new expected. Any package not in `AGENTS.md`: stop and report.

## 4. Design sections you implement (binding: `docs/design/frontend.md`)
- §11 Sprint 3 product screens, exactly as listed: `ProductListScreen` (`/products`: search, low-stock filter, archived toggle, paging with `pageSize` 20, pull to refresh), `ProductDetailScreen`, `ProductFormScreen` (create and edit; `openingQuantity` only for Owner), `UnitFormScreen` (add, edit, delete), `StockAdjustmentScreen`, `StockCountScreen` (`changed: false` → "Count matches, nothing changed"), `MovementListScreen` (paged, reason labels, signed change, balance after, note), each with its four states.
- §1 layers for the `products` feature (data sources, DTOs, repository, use cases, notifiers), §5 decimal input parsing/formatting (Western digits; Arabic-Indic input accepted), §2 providers, §3 routes (already declared in 2a: replace the placeholders).
- §12 fake backend: add `FakeProductsHandler` for **P1–P12** with the contract's validation, precision rules, duplicate checks (name, unit name, unit barcode in the shop, product barcode), archive rules, owner checks (`403 Auth.Forbidden`, `403 Product.OpeningStockOwnerOnly`), the opening-stock `StockCount` movement with note "Opening stock", movements, low-stock filter and search (Arabic-normalized), paging. Seed: the Arabic pharmacy seed from §12.1 (about 30 products, some low stock, one negative). Contract fixture tests for every P endpoint under `test/contract/`.

## 5. API contract (v1.4, binding sections)

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
- **Account lockout (v1.4):** 5 failed logins in a row on an existing account lock it for **15 minutes**. While locked, login returns `423 Auth.LockedOut` with `Retry-After` (whole seconds until the lockout ends, at least 1), **even with the correct password**. A successful login resets the failure count.
- **Rate limiting (v1.4):** `POST /api/auth/login` and `POST /api/auth/register` each allow **10 requests per minute per client IP** (fixed window). The 11th returns `429 Auth.TooManyRequests` with `Retry-After` (seconds until the window resets). The client shows the message and does not retry automatically before `Retry-After`.
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
| P1 | GET | /api/products | user | 200, 400, 401, 403 | 1.6 | implemented |
| P2 | GET | /api/products/{id} | user | 200, 401, 403, 404 | 1.6 | implemented |
| P3 | POST | /api/products | user | 201, 400, 401, 403, 409 | 1.6 | implemented |
| P4 | PUT | /api/products/{id} | user | 200, 400, 401, 403, 404, 409 | 1.6 | implemented |
| P5 | POST | /api/products/{id}/archive | owner | 204, 401, 403, 404 | 1.6 | implemented |
| P6 | POST | /api/products/{id}/units | user | 201, 400, 401, 403, 404, 409 | 1.6 | implemented |
| P7 | PUT | /api/products/{id}/units/{unitId} | user | 200, 400, 401, 403, 404, 409 | 1.6 | implemented |
| P8 | DELETE | /api/products/{id}/units/{unitId} | user | 204, 400, 401, 403, 404, 409 | 1.6 | implemented |
| P9 | POST | /api/products/{id}/adjustments | owner | 201, 400, 401, 403, 404 | 1.6 | implemented |
| P10 | POST | /api/products/{id}/stock-counts | owner | 200, 400, 401, 403, 404 | 1.6 | implemented |
| P11 | GET | /api/products/{id}/movements | user | 200, 400, 401, 403, 404 | 1.6 | implemented |
| P12 | GET | /api/products/lookup | user | 200, 400, 401, 403, 404 | 4 | planned |

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

### 5. Products, units, stock (step 1.6; P12 in Sprint 4)

Roles: Owner and Staff can create and edit products and units; only the Owner archives, adjusts stock and records stock counts (roadmap assumptions).

#### P1 `GET /api/products` (user)
Query: `search` (optional, max 100; matched against the normalized name, Arabic-normalized), `lowStock` (bool, default `false`: only `quantity <= lowStockThreshold`), `includeArchived` (bool, default `false`), `page`, `pageSize`.
Sorted by normalized name. `200` paged `ProductListItem`.
`lowStock=true` is served by `GetLowStockQuery` (partial index `ix_products_low_stock`).

#### P2 `GET /api/products/{id}` (user)
`200` `ProductDetail`. `404 Product.NotFound` (also for another shop's product).

#### P3 `POST /api/products` (user)
```json
{
  "name": "بنادول اكسترا",
  "barcode": "6221234567890",
  "category": "مسكنات",
  "baseUnitName": "شريط",
  "costPrice": "12.50",
  "baseUnitSellPrice": "15.00",
  "lowStockThreshold": "5.000",
  "openingQuantity": "24.000"
}
```
`barcode`, `category` optional (max 64 / 100); `lowStockThreshold` optional (default `"0.000"`).
`openingQuantity` optional (quantity in the base unit, `>= 0`, **Owner only**): when present and greater than zero, the handler records a `StockCount` movement with note `"Opening stock"` in the **same transaction** as the product, so every quantity has a movement behind it. Absent or `"0.000"`: the product starts at `"0.000"` with no movement. A Staff request that includes `openingQuantity` → `403 Product.OpeningStockOwnerOnly` (nothing is created).
`201` `ProductDetail`, header `Location: /api/products/{id}`.
Errors: `400 Product.NameRequired`, `ProductUnit.NameRequired`, `Precision.TooManyDecimals`, `Precision.Negative`, `Precision.OutOfRange`; `403 Product.OpeningStockOwnerOnly`; `409 Product.DuplicateBarcode` (barcode used by another non-archived product of the shop).

#### P4 `PUT /api/products/{id}` (user)
`{ "name", "barcode", "category", "costPrice", "lowStockThreshold" }` (all required except `barcode`, `category`). Base-unit name and price are changed through P7.
`200` `ProductDetail`. Errors: `400` as P3, `404 Product.NotFound`, `409 Product.Archived`, `409 Product.DuplicateBarcode`.

#### P5 `POST /api/products/{id}/archive` (owner)
`204`. Idempotent. `404 Product.NotFound`, `403 Auth.Forbidden` (Staff).

#### P6 `POST /api/products/{id}/units` (user)
`{ "name": "علبة", "factor": "3.000000", "sellPrice": "40.00", "barcode": null }` → `201` `UnitDto`, `Location: /api/products/{id}/units/{unitId}`.
Errors: `400 ProductUnit.NameRequired`, `Precision.NotPositive` (factor), `Precision.TooManyDecimals`, `Precision.Negative`, `Precision.OutOfRange`; `404 Product.NotFound`; `409 Product.Archived`, `409 ProductUnit.DuplicateName`, `409 ProductUnit.DuplicateBarcode` (barcode used by any unit in the shop).

#### P7 `PUT /api/products/{id}/units/{unitId}` (user)
Same body as P6 → `200` `UnitDto`. The base unit's factor must stay `"1.000000"`.
Errors: as P6, plus `400 ProductUnit.BaseUnitFactorFixed`, `404 ProductUnit.NotFound`.

#### P8 `DELETE /api/products/{id}/units/{unitId}` (user)
`204`. Errors: `400 ProductUnit.BaseUnitCannotBeRemoved`, `404 Product.NotFound`, `404 ProductUnit.NotFound`, `409 Product.Archived`, `409 ProductUnit.InUse` (referenced by an invoice or sale line; Sprint 2+).

#### P9 `POST /api/products/{id}/adjustments` (owner)
Manual correction (a new movement; nothing is edited, AGENTS.md rule 2).
```json
{ "quantityChange": "-2.000", "unitId": null, "note": "Expired, thrown away" }
```
`unitId` optional (default: base unit); the change is converted with `ProductUnit.ToBase`. `note` required, max 500.
`201` `StockMovementDto` (reason `ManualAdjustment`).
Errors: `400 Stock.ZeroChange`, `Stock.NoteRequired`, `Precision.TooManyDecimals`, `Precision.OutOfRange`; `404 Product.NotFound`, `404 ProductUnit.NotFound`.
Allowed on archived products (late correction).

#### P10 `POST /api/products/{id}/stock-counts` (owner)
```json
{ "countedQuantity": "26.000", "unitId": null }
```
`200`:
```json
{ "changed": true, "quantity": "26.000", "movement": { "...": "StockMovementDto" } }
```
When the count equals the current quantity: `changed: false`, `movement: null` (no zero movements).
Errors: `400 Precision.Negative`, `Precision.TooManyDecimals`, `Precision.OutOfRange`; `404 Product.NotFound`, `404 ProductUnit.NotFound`.

#### P11 `GET /api/products/{id}/movements` (user)
Query: `page`, `pageSize`. Newest first. `200` paged `StockMovementDto`. `404 Product.NotFound`.

#### P12 `GET /api/products/lookup?barcode=...` (user, Sprint 4)
Finds a non-archived product by product barcode or unit barcode (quick sale).
`200` `{ "product": ProductListItem, "unit": UnitDto }` (`unit` = the unit whose barcode matched, or the base unit for a product barcode). `400 Validation.Failed` (missing barcode), `404 Product.NotFound`.

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

### 10. Decisions relevant here

4. `pageSize > 100` is rejected (400), not clamped.
9. (v1.1) Optional `openingQuantity` on P3, Owner only: a `StockCount` movement with note "Opening stock" in the same transaction. Staff → `403 Product.OpeningStockOwnerOnly`.
10. Adjustments and counts accept an optional `unitId` and convert with `ProductUnit.ToBase`.
11. `GET /api/products/{id}/movements` added (served by `stock_movements (shop_id, product_id, created_at DESC)`).
12. Barcode lookup (P12) searches product and unit barcodes of non-archived products.
16. `ProductUnit.InUse` (409) protects history: a unit referenced by invoice or sale lines cannot be deleted.


## 6. Tests
Unit tests for every use case and notifier (list paging/search/filter, detail, form create/edit with validation and every mapped failure, units, adjustment, count, movements); fake handler tests with contract fixtures for P1–P12; **widget tests for every screen in 4 states × 2 languages**, a dark smoke test per screen, RTL checks on list and form, Owner vs Staff visibility. All earlier tests stay green.

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
Leave your changes in the working tree on `feature/products`. The orchestrator verifies and commits.

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
