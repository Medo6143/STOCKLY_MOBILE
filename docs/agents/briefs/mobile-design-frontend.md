Read AGENTS.md fully before starting.

# Brief: mobile-design-frontend

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`) · Lane: MOBILE · Contract version: **v1.2** (`docs/api/contract.md` in this repo, a copy of `stockly-backend/docs/api/contract.md`)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md or the contract, **stop and report** instead of guessing.

## 1. Goal and why
Stockly's Flutter app (Arabic first, RTL, light and dark) has no code yet. Before any code, the whole frontend design must be fixed in one document, so the implementation briefs that follow can be exact and the app can be built against the API contract with fake repositories before the backend is live. Write `docs/design/frontend.md`. You write documentation only: no Flutter project, no code beyond short signatures and snippets in the document.

## 2. Scope
**You may change:** `docs/design/frontend.md` (new file).

**You must NOT touch:** anything else, in particular `AGENTS.md`, `CLAUDE.md`, `brand/`, `docs/api/`, `docs/agents/`, `docs/sprints/`, `docs/structure.md`. Do not run `flutter create`, `flutter pub`, `dart`, or any `git` command that changes state. Reading files and running `flutter --version` are fine. The backend repository `D:\FLUTTER\stockly` is read-only for you (you may read its `docs/`).

## 3. Critical rules for this task
Full rules: `AGENTS.md` (mobile rules 34–39 and conventions). Copied here:
- 34. Every screen handles four states: loading, empty, error, data, using the shared `AsyncStateView`.
- 35. No hardcoded strings, colors, sizes or durations. Strings from ARB files, colors and spacing from theme tokens (`brand/` is the source).
- 36. Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`. Never `left`/`right`.
- 37. State is immutable (freezed). No business logic in widgets.
- 38. Tokens in `flutter_secure_storage` only. No API keys in the app, ever.
- 39. Respect "reduce motion": animations, including the splash, show their final frame.
- Architecture: `presentation (widgets + Riverpod notifiers) → domain (use cases, entities, repository interfaces) → data (repository impls, Dio data sources, DTOs)`. Widgets never import Dio or data-layer classes.
- Repositories return `Result<T, Failure>` (sealed class), never throw to the UI.
- Shared product rules (from the backend `AGENTS.md`): money and quantities are **decimal**, never `double` (the API sends them as strings; parse with the `decimal` package); the shop comes from the token, never from the app; scans and sales carry a client-generated `clientRequestId` reused on every retry (ADR-0006 in the backend repo).
- **Packages.** Allowed: Flutter SDK, `flutter_riverpod`/`riverpod_annotation`, `go_router`, `dio`, `freezed` + `json_serializable` (+ `build_runner`), `drift`, `flutter_animate`, `flutter_secure_storage`, `decimal`, `intl` + `flutter_localizations`, `connectivity_plus` + `workmanager` (ADR-0006), `flutter_native_splash` (brand spec), `very_good_analysis`, `mocktail`. **Any other package** (for example camera, image picker, image compression, barcode scanning): do not assume it. List it in a "Packages that need approval" table with the reason and an alternative, and design around an interface so the choice can change.

## 4. Inputs to read
- `docs/api/contract.md` (v1.2): every endpoint the app uses, conventions (§1), shared schemas (§3), error codes (§9). Field names, types, status codes and codes are binding.
- `brand/stockly-brand.html` and `brand/stockly-mark.svg`: colors, typography, splash animation spec and timings.
- `docs/structure.md`: the folder structure.
- `AGENTS.md`.
- Backend docs, read-only, for behaviour behind the API: `D:\FLUTTER\stockly\docs\roadmap.md` (Sprints 3–4 scope), `D:\FLUTTER\stockly\docs\adr\0006-offline-scan-idempotency.md`.

## 5. What `docs/design/frontend.md` must contain
1. **Layers per feature** (auth, products, invoices, sales, dashboard, settings, splash): folders, which class lives where, and the dependency direction.
2. **Riverpod provider graph**: core providers (Dio, token storage, auth state, locale, theme) and per-feature providers/notifiers, as a Mermaid diagram plus a table (name, type, depends on, lifetime).
3. **go_router**: every route (path, screen, auth required), the auth redirect (splash → restore session with `GET /api/auth/me` → home or login), deep links if any.
4. **Dio interceptors**: auth header; **refresh with a request queue** (contract §1.4: on 401 refresh once, retry once, concurrent 401s share one refresh, failure → sign out); `Accept-Language`; `X-Correlation-Id`; **ProblemDetails → `Failure` mapping** by `code` (sealed `Failure` hierarchy covering every code in contract §9 the app can receive, plus network/timeout/unknown).
5. **Decimal handling**: how money, quantities and factors (strings) are parsed into `Decimal`, formatted for `ar` and `en` (Arabic-Indic digits or not: decide and justify), and sent back as strings with the right number of decimals.
6. **Offline scan queue**: Drift schema (tables, columns, indexes), states of a queued scan, the sync worker (`connectivity_plus` + `workmanager`), retry and backoff, `clientRequestId` reuse, handling of `200` repeat vs `202` new, quota/rate-limit errors (`429`), and what the user sees.
7. **Theme**: tokens from `brand/` mapped to a `ThemeExtension` (`StocklyColors`, spacing, radii, durations, typography) for light and dark; fonts for Arabic and English.
8. **l10n**: ARB setup (`ar` default, `en`), key naming, how ProblemDetails `code`s map to localized messages, RTL handling.
9. **`AsyncStateView`**: API and how every screen uses it for loading, empty, error, data.
10. **Splash**: native splash (`flutter_native_splash`) plus the animated splash from `brand/stockly-brand.html`, exact timings, and the reduce-motion behaviour (rule 39).
11. **Screens for Sprints 3–4** (list with route, purpose, the contract endpoints each calls, and its 4 states).
12. **Fake repositories**: how the app runs against the contract without a backend (fakes that return contract-shaped data and the same `Failure`s as the real ones, SOLID "L"), and how to switch to the real Dio data sources later.
13. **Testing plan**: unit tests for use cases and notifiers; widget tests for the 4 states × 2 languages of every screen; golden tests or not (decide).
14. **Packages that need approval** (see §3).
15. **Open questions**.

Keep it concrete: class and file names, provider names, route paths, Drift column types. Every endpoint, field and error code must match contract v1.2 exactly.

## 6. Checks you must pass before finishing
- Every Mermaid block is valid Mermaid syntax.
- Every endpoint, field and error code you mention exists in `docs/api/contract.md` v1.2.
- Every rule in §3 is applied; say where.
- `git status --short` shows only `docs/design/frontend.md`.

## 7. Do not commit, push or merge.
Leave your changes in the working tree. The orchestrator reviews and commits.

## 8. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and where in the design>
Files changed: <list>
Check outputs: <git status --short>
Decisions taken: <list, with reason>
Packages that need approval: <list or "none">
Open questions: <list or "none">
Contract deviations: NONE   (anything else: stop before finishing and report it)
```
