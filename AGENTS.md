# AGENTS.md — Stockly mobile (Flutter)

This file is the contract for anyone writing code in `stockly-mobile`: humans and AI agents. Read it fully before your first change. If a task conflicts with a rule here, **stop and ask**.

The backend lives in `stockly-backend` (locally `D:\FLUTTER\stockly`), see its ADR-0011 (polyrepo). The app talks to the backend **only** through the API contract: `docs/api/contract.md` (human, versioned copy of `stockly-backend/docs/api/contract.md`) and `stockly-backend/docs/api/openapi.json`. Brand assets: `brand/`. Rule numbers are kept from the original shared `AGENTS.md` (34–39).

## Shared product rules (apply here too)
- Money and quantities are **decimal**, never `double`. The API sends them as strings (`"125.50"`, `"1.500"`); parse and format them with the `decimal` package.
- The shop (tenant) comes from the access token, never from the app. The app never sends a shop id.
- `POST /api/invoices/scan` and `POST /api/sales` carry a client-generated `clientRequestId` (UUID), created once and reused on every retry; a repeat returns the existing resource (`200`).
- On `401` the client refreshes the token once and retries the request once; concurrent `401`s share one refresh.
- Errors are RFC 7807 ProblemDetails; the app switches on `code`, never on `title`/`detail`.
- Never log tokens, passwords or full images. No API keys in the app, ever.
- No magic strings, no dead code, no commented-out code, no `TODO` without an issue link.
- Never delete, skip or weaken a test to make the build pass.
- Commits: Conventional Commits, small, one concern each. Branches `feature/<name>`, `fix/<name>`, `chore/<name>`, `docs/<name>`.

## Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter stable, Riverpod, go_router, Dio, freezed + json_serializable, Drift (offline queue), flutter_animate |
| Tests | flutter_test, mocktail |

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
```

## Architecture

Mobile: `presentation (widgets + Riverpod notifiers) → domain (use cases, entities, repository interfaces) → data (repository impls, Dio data sources, DTOs)`. Widgets never import Dio or data-layer classes.

## Rules (numbers kept from the original AGENTS.md)

34. Every screen handles four states: loading, empty, error, data, using the shared `AsyncStateView`.
35. No hardcoded strings, colors, sizes or durations. Strings from ARB files, colors and spacing from theme tokens (`brand/` is the source).
36. Use `EdgeInsetsDirectional`, `AlignmentDirectional`, `start`/`end`. Never `left`/`right`.
37. State is immutable (freezed). No business logic in widgets.
38. Tokens in `flutter_secure_storage` only. No API keys in the app, ever.
39. Respect "reduce motion": animations, including the splash, show their final frame.

## Conventions

**Dart**
- `very_good_analysis` lints, no ignores without a comment explaining why.
- One public widget per file. File names `snake_case`.
- Providers live next to the feature, named `<thing>Provider`, notifiers `<Thing>Notifier`.
- Repositories return `Result<T, Failure>` (sealed class), never throw to the UI.

## Testing

- Unit tests for use cases and notifiers; widget tests for all 4 states of each screen, in both `ar` and `en`.

## Review checklist (in addition to the shared one)

- [ ] Mobile: RTL checked, 4 states, light + dark, strings in ARB
