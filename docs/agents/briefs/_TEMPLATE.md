Read AGENTS.md fully before starting.

# Brief: <lane>-<task>

Repository: `stockly-mobile` · Lane: MOBILE · Contract version: v<N> (`docs/api/contract.md`)

You have not seen the conversation that produced this brief. Everything you need is here or in the files it links. If something you need is missing or contradicts AGENTS.md or the contract, **stop and report** instead of guessing.

## 1. Goal and why
<What to build and why. One paragraph.>

## 2. Scope
**You may change:** <exact paths>

**You must NOT touch:** anything not listed above, in particular `docs/api/contract.md` (only the orchestrator changes it).

## 3. Critical rules for this task
Full rules: `AGENTS.md`. The ones that matter most here (copied):
- <rule number and text>

## 4. API contract (relevant section)
<Copied from docs/api/contract.md with its version. Field names, types, status codes and error codes are binding.>

## 5. Steps
1. <Tests first>
2. <Implementation>
3. <Docs>

## 6. Checks you must pass before finishing
```bash
flutter analyze
flutter test
dart format --set-exit-if-changed .
```
Zero issues, zero failures. Never skip, delete or weaken a test.

## 7. Do not commit, push or merge.
Leave your changes in the working tree. The orchestrator verifies and commits.

## 8. Final report (exact format)
```
AGENTS.md read: yes
Rules applied: <numbers and one line each>
Files changed: <list>
Check outputs: <tails of flutter analyze, flutter test, dart format>
Decisions taken: <list, with reason>
Open questions: <list or "none">
Contract deviations: NONE   (anything else: stop before finishing and report it)
```
