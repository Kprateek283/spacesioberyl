# Automated Testing Strategy

Goal: a way to know, automatically and repeatably, that the backend and frontend are working correctly on their own **and** integrated correctly with each other — instead of relying on manual click-through or self-reported QA docs like `QA_REPORT.md`, which this audit found to be inaccurate in several places.

This repo already has most of the *pieces* needed (Go integration tests, Flutter integration tests, a Postman collection). They're just disconnected, stale, and not run automatically. Below is what exists, what's broken about it, and what to add — ordered by effort/value.

## What already exists

| Layer | Tool | Location | Current state |
|---|---|---|---|
| Backend unit tests | `go test` | none under `backend/internal/**` | **Doesn't exist.** Zero unit test files anywhere in `internal/`. |
| Backend integration tests | `go test` (live server) | `backend/tests/*.go` | Exists but fails — wrong seeded credentials (`admin@company.com` vs actual `admin@gmail.com`), a broken multi-digit-ID test helper, and a self-inflicted rate-limit collision. See [01-backend-issues.md](01-backend-issues.md). |
| Backend smoke test | bash + curl | `backend/qa_test.sh` | Has correct credentials, looks functional, but isn't run in CI. |
| API contract collection | Postman | `Spacesio_Beryl_Postman.json`, `test_collection.json` | Exists, has the same wrong credentials as the Go tests; not automated (no Newman run in CI). |
| Frontend unit/widget tests | `flutter test` | `frontend/test/widget_test.dart` | **Fails immediately** — it's the untouched Flutter-starter counter test, never adapted to this app. |
| Frontend integration tests | `flutter test integration_test/` | `frontend/integration_test/*.dart` | Substantive (real multi-step flows), but stale — they reference navigation tabs/screens that no longer exist in the current router/shell. Would not currently pass. |
| CI pipeline | — | none found | No GitHub Actions / CI config found anywhere in the repo. Nothing above runs automatically today; all of it is manual, which is exactly how the stale tests and contradictory QA docs happened. |

## Recommended plan

### 1. Fix what's broken before adding anything new (highest leverage, lowest effort)
- Update `backend/tests/*.go` and root `test.sh` to use the real seeded credentials (`admin@gmail.com`/`admin123`), matching `backend/qa_test.sh`.
- Fix `TestHRLeaveStateLogic`'s ID-to-string conversion so it isn't limited to single-digit IDs.
- Space out or reduce PIN-verification calls in the fuzz/business-logic tests so they don't trip their own new rate limiter.
- Replace `frontend/test/widget_test.dart` with a real smoke test for this app (e.g. renders the login screen and finds expected text) — the current one is not testing this app at all.
- Update `frontend/integration_test/*.dart` to match the current 3-tab navigation, or — better — fix the navigation gap in [02-frontend-issues.md](02-frontend-issues.md) first and then update the tests to cover the restored navigation.

Once these pass locally, they become meaningful signals instead of noise everyone ignores.

### 2. Wire it all into CI so it runs on every push/PR
None of this catches anything if it only runs when someone remembers to run it by hand — which is how the app ended up with a broken nav, a mock upload service, and contradictory QA reports in the first place. Add a CI workflow (e.g. GitHub Actions) with two jobs:
- **Backend job:** spin up `docker-compose` (Postgres/Redis/RabbitMQ/MinIO), run migrations, `go build ./...`, `go vet ./...`, `go test ./...`.
- **Frontend job:** `flutter analyze`, `flutter test` (unit/widget), and `flutter test integration_test/` against the docker-composed backend from the job above (or a lightweight mock server for pure-frontend logic tests).

This alone would have caught: the wrong test credentials, the failing widget test, the stale integration tests, and the `go vet` cleanliness regressing in the future.

### 3. Automate the Postman collection as a black-box API contract check
`Spacesio_Beryl_Postman.json` already encodes the full API surface. Running it via [Newman](https://github.com/postmanlabs/newman) (Postman's CLI runner) in CI against a freshly migrated+seeded backend gives a fast, language-agnostic check that every documented endpoint still behaves as documented — independent of whether the Go or Flutter code changed. This is the most direct way to answer "is the backend still doing what the frontend expects" without writing new test code, since the collection already exists (just needs the credential fix above).

### 4. Close the backend↔frontend contract gap with generated types
This audit found real backend/frontend drift historically (BUG-B01 enum mismatch, now fixed) and flagged a DTO-by-DTO cross-check as an unfinished gap. The most durable fix, not just a one-time check, is to stop hand-writing both sides:
- Generate an OpenAPI spec from the Go handlers (or hand-write one and validate handlers against it with a tool like `oapi-codegen`).
- Generate the Dart API client/models from that OpenAPI spec instead of hand-writing `api_client.dart` request/response shapes.
This turns "does the frontend's expected shape match the backend's actual response" from a manual audit question into a compile-time guarantee — a mismatch becomes a build failure instead of a runtime bug discovered by a user.

### 5. Add real backend unit tests, not just integration tests
Right now `internal/**` has zero unit tests — every existing test requires a live docker-compose stack, which makes them slow and fragile (as seen with the credential/rate-limit issues above). Add table-driven `go test` unit tests for pure business logic that doesn't need a database or network:
- Ghost Mode cash-payment enforcement logic (`quotation_svc.go`)
- OTP generation/validation math (`iam_service.go`)
- Order status transition rules (`logistics_svc.go`) — this would have directly caught the missing `ready_for_dispatch` transition found in this audit.
Use `sqlmock` or an interface-based repository mock to unit-test service-layer logic without spinning up Postgres.

### 6. Add Flutter widget tests per screen, plus golden tests for visual consistency
Given the UI consistency problems found in [03-ui-ux-wireframe-audit.md](03-ui-ux-wireframe-audit.md) (three competing color systems, ad hoc styling), golden tests (`flutter test --update-goldens` / `matchesGoldenFile`) on key screens would catch future regressions in visual consistency automatically, and widget tests on individual screens would catch the kind of dead-button/orphaned-navigation issues found in this audit (a widget test asserting the bottom nav has all expected destinations would have caught the navigation gap immediately).

### 7. End-to-end smoke test across the real stack
Once the above is in place, add one final "does the whole thing actually work together" check: `flutter drive` (or the `patrol` package, which handles native permissions better) driving the real Flutter app against the real docker-composed backend through one full golden-path journey per module (login → PIN → create lead → create quotation → approve → order appears in Logistics → create PO → dispatch → execution job → signoff). This is the automated equivalent of the manual walkthrough in `FRONTEND_TESTING_GUIDE.md`, but running on every merge instead of by hand — and it would have caught the fact that most of these screens aren't reachable from the actual navigation today.

## Summary: minimum viable setup to "know everything is working"

If effort is limited, do these three in order — they compound:
1. Fix the credential mismatch in existing backend tests + fix the Flutter starter widget test (near-zero effort, immediately turns two currently-useless test suites into real signals).
2. Add a GitHub Actions workflow running `go test ./...` + `flutter test` + Newman-run Postman collection on every PR (this is the actual "automatic" part — nothing above helps if it isn't wired to run without a human remembering to).
3. Add the OpenAPI-generated Dart client (#4) — this is the single highest-leverage change for "backend and frontend are integrated properly," because it converts an entire category of bug (shape mismatches) from a runtime surprise into a build error.
