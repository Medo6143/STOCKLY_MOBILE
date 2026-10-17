Read AGENTS.md fully before starting.

# Brief: mobile-5-design-refresh

Repository: `stockly-mobile` (`D:\FLUTTER\stockly-mobile`), branch `feature/design-refresh` (already checked out, based on `main` with Sprint 4 merged) · Lane: MOBILE · Contract version: **v1.5** (no API change in this brief)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md or the design, **stop and report** instead of guessing.

## 1. Goal and why
The product owner tried the app on the emulator and asked for three things: a **modern design**, a **profile page of its own**, and **animation**. Today the screens are correct but plain (flat lists, plain forms, settings as a tab). This brief refreshes the visual layer of every existing screen without changing behaviour, data flow, routes' meaning or API calls.

## 2. Scope
**You may change / create:** `lib/**`, `test/**`, `README.md` (screens section only).

**You must NOT touch:** `AGENTS.md`, `CLAUDE.md`, `brand/**`, `docs/**`, `android/**`, `pubspec.yaml`/`pubspec.lock` (no new packages: `flutter_animate` is already in the stack and is enough; the `animations` package is **not** approved), `.gitignore`.

**Git and machine safety:** never run git commands that change the working tree or history. Never kill processes by image name; stop only processes you started, by PID. **Do not start the emulator and do not install or launch the app** (the orchestrator shows the result to the product owner). Never change anything outside this repository except the tool caches.

**Environment:** in every shell, before any `flutter`/`dart` command:
```bash
export PATH="/d/dev/flutter/bin:$PATH" PUB_CACHE='D:\dev\pub-cache' GRADLE_USER_HOME='D:\dev\gradle' ANDROID_USER_HOME='D:\dev\android-user' ANDROID_HOME='D:\Android\Sdk' TEMP='D:\FLUTTER\_tmp' TMP='D:\FLUTTER\_tmp'
```

## 3. Design direction (binding)
Brand colors and fonts stay exactly as in `docs/design/frontend.md` §7 and `brand/` (navy, ink, mint, mint-soft, Arabic-first typography). "Modern" here means:
- **Depth and surfaces:** cards on `surface` with soft, theme-aware shadows (light) or a 1 px `line` border plus slightly lighter surface (dark); larger corner radii for hero cards. Add tokens rather than literals: `StocklyRadii.xxl = 24` for hero cards and sheets, and a `StocklyElevation` theme extension (shadow colour from `ink` with alpha, blur and offset per level 0/1/2). Record them as derived tokens in a code comment (brand approval pending, like the existing derived tokens).
- **Hero headers:** the dashboard and the profile page get a header with a navy → ink gradient (dark: background → surface), white/`ink`-on-dark text, and the shop name; content cards overlap the header's bottom edge.
- **Lists:** product, invoice, sale and movement rows become rounded cards with a leading tinted icon or initials badge, clear primary/secondary text, status chips with soft fills (`mintSoft`, `warningSoft`, `dangerSoft`), and numbers in `LtrIsolate`.
- **Forms:** filled text fields with rounded borders and a mint focus ring, grouped in section cards with a title; primary buttons full-width, pill radius, with a pressed scale effect.
- **Bottom navigation:** Material 3 `NavigationBar` with an animated pill indicator; tabs after this brief: **Dashboard (home) · Products · Invoices · Sales · Profile** (labels from ARB). Settings is no longer a tab.
- **Empty and error states:** a larger illustration-style icon in a soft circle, title, body and action, with an entrance animation.
- **Loading:** skeleton placeholders with a subtle shimmer (built with `flutter_animate` `shimmer`), shaped like the content, instead of bare spinners in lists and cards.

## 4. Profile page (new, binding)
- Route `/profile` (add to `RoutePaths` and the router; it is the 5th tab). The existing settings screen moves to `/profile/settings` and keeps its content (language, theme, sign out warning logic); the old `/settings` path redirects to `/profile/settings` so old links keep working (test it).
- Content, from the session already in memory (`currentSessionProvider` / A5 data; **no new endpoint**, no edit form, since `PATCH /api/auth/me` is not in the contract):
  - Header: avatar circle with the user's initials (Arabic and Latin initials handled) inside a mint gradient ring, full name, email, phone if present, role badge (Owner/Staff).
  - Shop card: shop name, shop type label, governorate, address/phone if present.
  - Actions list (cards with icon, title, chevron that flips in RTL): Settings (language and theme), Sign out (same confirmation and pending-scans/pending-sales warning as today).
- Four states via `AsyncStateView`: loading (skeleton header), empty not applicable (always has a session; document the substitute like other screens), error (session read failure), data.

## 5. Animation (binding)
All through `flutter_animate` or implicit animations, durations from `StocklyDurations` (add tokens if needed, e.g. `stagger 40 ms`, `entrance 400 ms`), curves named in one place, and **everything goes through `StocklyMotion` so "reduce motion" shows the final frame with no ticking** (rule 39; test with `transientCallbackCount == 0` under reduce motion for at least the dashboard, list and profile).
- Page transitions: a fade-through (fade + slight scale) for tab switches and a shared-axis-like slide (direction-aware: from the end edge in LTR, from the start edge in RTL) for pushes, via `CustomTransitionPage` in go_router.
- Staggered entrance (fade + 8 dp slide up) for list items and dashboard cards, only on first load, not on every rebuild or page fetch.
- Animated counters on dashboard numbers (count up from 0 to the value; money keeps 2 decimals while animating, using `Decimal` interpolation steps, never `double` for the displayed value).
- Hero animation for a product's name/badge from list to detail.
- Animated bottom-nav indicator, button press scale, chip selection animation, status chip colour transitions.
- Success feedback: an animated check after invoice confirm and after a sale is recorded.
- Pull-to-refresh keeps the platform indicator.

## 6. Critical rules
- 34: four states on every screen, including the new profile screen.
- 35: no hardcoded strings, colors, sizes or durations (new tokens for everything new).
- 36: directional APIs only; slide directions flip in RTL.
- 37: no business logic in widgets; visual-only widgets may be stateless with animation controllers owned by `flutter_animate`.
- 39: reduce motion respected everywhere.
- Never weaken a test. Behaviour tests stay; update finders only where a widget type legitimately changed, and say which in the report.

## 7. Tests
Profile screen 4 states × ar/en, dark smoke test, RTL check; `/settings` redirect; bottom nav has 5 tabs in the right order in ar and en; reduce-motion tests (no ticking) for dashboard, product list and profile; counter shows the exact final value; stagger runs only on first load; transitions direction-aware in RTL. All earlier tests stay green.

## 8. Checks
```bash
dart run build_runner build --delete-conflicting-outputs
flutter gen-l10n
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
flutter build apk --debug --dart-define=STOCKLY_BACKEND=fake
```

## 9. Do not commit, push or merge.

## 10. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <summary by folder>
Check outputs: <tails of each command, with test counts>
Tests changed (finders only): <list with reason, or "none">
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE
```
