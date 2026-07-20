# Backend Issues (Go — `backend/`)

Independently re-verified against current source with `go build ./...` (clean), `go vet ./...` (clean), `go test ./...` (fails — see Testing section), and direct `git log`/`git ls-files` checks. Severity: Critical / High / Medium / Low.

**Scope note (2026-07-10):** per explicit instruction, no backend code changes are made from this point forward — this file is documentation-only for the backend. All fixes below are still open. Frontend fixes were applied separately (see [02-frontend-issues.md](02-frontend-issues.md)).

## New findings not fixed (documented only)

- **`backend/tests/business_logic_test.go:14-15`** — `getBaseToken` hardcodes login as `admin@company.com`/`newpass123`. The actual seeded credentials (`db/migrations/000002_seed_default_iam.up.sql`) are `admin@gmail.com`/`admin123`. This means `TestGhostModeLogic` and `TestHRLeaveStateLogic` cannot pass against a freshly migrated DB — confirmed live (wrong creds → `401`, right creds → `200`). Fix: change the two literals to the real seeded credentials.
- **`backend/tests/business_logic_test.go:131-139`** — `TestHRLeaveStateLogic` converts a leave ID to a URL path segment via `string(rune('0' + leaveID))`, which only works for single-digit IDs and explicitly `t.Fatalf`s for anything else (`if leaveID > 9 { t.Fatalf(...) }`). Breaks on any reasonably-used/reused database. Fix: use `strconv.Itoa(leaveID)` instead.
- **`backend/tests/api_fuzz_test.go:19-24`** — the comment says "we will just fetch the token once and use it," but the code actually calls `getPINToken(t, getBaseToken(t), "1234")` *inside* `f.Fuzz(func(...) {...})`, so it re-fetches a token (fresh `/login` + `/iam/verify-pin` call) on every single fuzz iteration. Combined with the `/iam/verify-pin` rate limiter (5 req/min/IP, added as a SEC-03 fix), this means the fuzz test trips its own rate limiter partway through and starts failing with 429s — a real regression interaction between the security fix and this test. Fix: move the `getPINToken`/`getBaseToken` call outside `f.Fuzz(...)`, fetching the token once before the fuzz loop starts (this requires widening the `getBaseToken`/`getPINToken` helper signatures from `*testing.T` to the `testing.TB` interface, since `f` here is a `*testing.F`).
- **Root `test.sh`** — same wrong credentials as `business_logic_test.go` (`admin@company.com`/`newpass123`). Only `backend/qa_test.sh` uses the correct seeded credentials.

## Blocker for a related frontend fix

The frontend audit ([02-frontend-issues.md](02-frontend-issues.md)) flagged that HR expense receipts, execution site-update photos, contractor check-in photos, and client sign-off signatures were all going through a `MockUploadService` that fakes a URL instead of uploading anything. Closing that properly requires a backend endpoint to actually receive the file — the only existing upload-capable route is `POST /api/v1/projects/{id}/docs` (BFF, scoped to CRM project documents; also runs with JWT auth bypassed per its own `NOTE` comment), which doesn't fit HR/Execution's use case. A generic authenticated `POST /api/v1/uploads` endpoint (multipart file + bucket field, reusing the existing `storage.UploadFile` helper) would close this. **Not implemented per the "no backend changes" instruction** — the frontend-side wiring for this was reverted back to the mock service so the app doesn't call a non-existent endpoint (see [02-frontend-issues.md](02-frontend-issues.md) for current status).

## Status of previously-reported issues (`qa_bug_report.md`)

Of 8 backend bugs, 4 security issues, 6 flow/integration bugs: **12 confirmed fixed, 4 partially fixed, 1 still fully present.** `QA_REPORT.md`'s blanket "Verified Fixed / READY FOR PRODUCTION" claim is largely accurate for backend logic bugs but overstates completeness on security and flow items, and misses several issues below that weren't caught because the test suite was never actually re-run.

| ID | Verdict | Notes |
|---|---|---|
| BUG-B01 Lead status enum mismatch | **Fixed** | Code and docs both consistently use `first_call`. |
| BUG-B02 Logistics skips service layer | **Fixed** | Proper repo→service→handler wiring now exists. (See EX-01 below — the same defect has resurfaced in Execution.) |
| BUG-B03 Ghost Mode not enforced on quotations | **Fixed** | `quotation_svc.go:31-33` rejects `cash` when ghost mode is off. |
| BUG-B04 OTP truncation | **Fixed** | Modulo now correctly applied in `iam_service.go:324`. |
| BUG-B05 `strconv.Atoi` errors ignored | **Fixed for path IDs**, still present for optional query filters (see below, Low). |
| BUG-B06 missing seed migration `down.sql` | **Fixed** | File exists and correctly reverses the seed. |
| BUG-B07 RabbitMQ global mutable channel | **Fixed correctly** | Channel-per-publish pattern now used everywhere; no shared-channel race remains. |
| BUG-B08 MinIO internal Docker hostname in URLs | **Fixed** | Configurable `MINIO_PUBLIC_URL` now used. |
| BUG-I01 `quote_approved` consumer auto-ack | **Fixed** | Manual ack/nack with requeue on failure. (See below — same bug still exists on a sibling queue.) |
| BUG-I02 WhatsApp goroutine uses `context.Background()` post-response | **Partially fixed** | Logistics dispatch path made synchronous (fixed). Still present in execution check-in (see below, Low). |
| BUG-I03 Escalation threshold doc mismatch (48h vs 72h) | **Fixed** | Now 48h in both code and docs. |
| BUG-I04 No follow-up cancellation on lead loss | **Fixed** | `lead_svc.go:71-75` cancels pending follow-ups. |
| BUG-I05 Order status not updated after PO creation | **Partially fixed** | See below. |
| BUG-I06 No DB transaction in quotation creation | **Fixed** | Proper `tx.Begin`/`defer Rollback`/`Commit`. |
| SEC-01 `JWT_SECRET=secret` hardcoded | **Still present** | Live and in active use — see Critical finding below. |
| SEC-02 WhatsApp token committed to git | **Fixed (verified via git history)** | `.env` was never committed, ever — `git log --all -- .env` is empty and `.gitignore` covers it. |
| SEC-03 No rate limiting on auth endpoints | **Partially fixed** | `/login`, `/iam/verify-pin`, `/iam/setup-pins` are rate-limited. `/password/forgot` and `/password/reset` are not. |
| SEC-04 Password hash returned in `ListUsers` | **Partially mitigated** | Response DTOs and `json:"-"` tags prevent leakage in practice, but the SQL still fetches the hash columns unnecessarily. |

---

## Critical

### JWT_SECRET=secret still live
- **File:** `.env` (repo root)
- The value actively signing every issued token today is the literal string `secret`. Verified live: a token minted by the running server decodes as `alg: HS256` and can be forged by anyone who guesses this trivial secret.
- **Failure scenario:** an attacker forges a JWT with `role: super_admin` and gets full API access without ever authenticating.
- **Fix:** rotate to a cryptographically random 32+ byte secret in the deployed `.env`, and add a startup check (see below) so a weak/empty secret can't ship silently again.

---

## High / Medium — Security

### No fail-fast on missing/weak `JWT_SECRET` at startup
- **File:** `backend/internal/config/config.go:40`
- `JWTSecret: getEnv("JWT_SECRET", "")` — if the env var is unset, the app starts anyway and signs tokens with an **empty string** secret, which is worse than the current "secret" value.
- **Fix:** reject startup if `JWT_SECRET` is empty or below a minimum length.

### CORS origin check is bypassable via prefix matching
- **File:** `backend/internal/middleware/cors.go:52`
- `strings.HasPrefix(host, "localhost")` — any hostname merely *starting with* "localhost" passes, e.g. `localhost.attacker.com`.
- **Failure scenario:** a page served from an attacker-controlled domain like `localhost.attacker.com` gets its `Origin` reflected back via `Access-Control-Allow-Origin`, defeating the intended dev-only allowlist — combined with any other vector that obtains a token (XSS, malicious extension), this removes the CORS boundary.
- **Fix:** exact match or suffix-with-dot-boundary, e.g. `host == "localhost" || strings.HasSuffix(host, ".localhost")`.

### CORS allowlist has no production configuration path
- **File:** `backend/internal/middleware/cors.go:9-14`
- Hardcodes only `localhost/127.0.0.1/::1/10.0.2.2`. A production Flutter-web build served from a real domain cannot call this API from a browser at all.
- **Fix:** make the allowlist env-driven for deployed frontend origins.

### Rate limiting missing on password-reset endpoints
- **File:** `backend/internal/iam/router.go:25-26`
- `/password/forgot` and `/password/reset` have no rate limiting, unlike `/login`/`/iam/verify-pin`/`/iam/setup-pins`. These are exactly the OTP-based endpoints most exposed to brute-force/email-enumeration abuse.
- **Fix:** apply the same `httprate.LimitByIP` middleware used elsewhere in this router.

### JWT parsing doesn't pin the signing algorithm
- **File:** `backend/internal/middleware/auth.go:49-51`, `backend/internal/iam/service/iam_service.go:249`
- `jwt.ParseWithClaims` never passes `jwt.WithValidMethods([]string{"HS256"})`. Not currently exploitable (only HMAC is used system-wide), but it's a missing defense-in-depth control.
- **Fix:** add `jwt.WithValidMethods([]string{"HS256"})` to both parse calls.

### `ListUsers` still fetches password/PIN hash columns unnecessarily
- **File:** `backend/internal/iam/repository/iam_repository.go:105-133`
- Response DTOs and `json:"-"` tags mean this doesn't currently leak, but the query still loads `password_hash`, `pin_hash`, `high_security_pin_hash` into memory for a list endpoint. If a future endpoint serializes the model directly, hashes leak.
- **Fix:** exclude these columns at the SQL level for list queries.

---

## Medium — Architecture

### Execution module's core handler bypasses the service layer (recurrence of BUG-B02)
- **File:** `backend/internal/execution/handler/execution_handler.go:17-22`, wired in `backend/internal/app/app.go:178-179`
- `ExecutionHandler` talks directly to `repository.ExecutionRepository` with no service layer in between — for `CreateInstaller`, `ListInstallers`, `ListJobs`, `GetMyJobs`, `CreateInstallation`, `AssignInstaller`, `SyncUpdates`, `GetUpdates`, `Signoff`. The sibling `ContractorHandler` in the same package correctly goes through `service.ContractorService`.
- **Failure scenario:** any future business rule (e.g., preventing double-assignment, validating installation completeness before signoff) has no consistent place to live.
- **Fix:** introduce `ExecutionService` mirroring the pattern used everywhere else, as was done to fix BUG-B02 in Logistics.

### Order never transitions to `ready_for_dispatch`
- **File:** `backend/internal/logistics/service/logistics_svc.go:55-67`
- `CreatePurchaseOrder` always sets order status to `partially_ordered`, never `ready_for_dispatch` even when all items are fully ordered — `module_flows.md` describes both transitions, but only one is implemented (grep confirms `ready_for_dispatch` appears only in docs, never assigned in Go code).
- **Fix:** implement the "all items ordered → ready_for_dispatch" check.

### `consumeInstallationSignoff` still uses auto-ack
- **File:** `backend/cmd/worker/main.go:173`
- Same bug class as the now-fixed BUG-I01, but on the installation-signoff queue: if the Financial Lock DB update fails after the message is already acked, the event is silently lost with no retry.
- **Fix:** switch to manual ack/nack like `consumeQuoteApproved`.

---

## Low

- **Query-parameter `Atoi` errors still swallowed:** `backend/internal/crm/handler/crm_handler.go:48`, `backend/internal/crm/handler/complaint_handler.go:50-51`, `backend/internal/hr/handler/expense_handler.go:51`. An invalid filter silently becomes `0` instead of a 400. Low since these are optional filters, not resource IDs.
- **WhatsApp check-in notification still fire-and-forget with `context.Background()`:** `backend/internal/execution/handler/contractor_handler.go:81-96`. If the process restarts between the HTTP response and goroutine completion, the notification is silently dropped. Best-effort by design; low impact.

---

## Testing infrastructure findings

- `go build ./...` and `go vet ./...` are clean.
- `go test ./...` **fails** — but the failures are in test fixtures, not production code:
  - `backend/tests/business_logic_test.go`, root `test.sh`, and `Spacesio_Beryl_Postman.json` all hardcode login as `admin@company.com` / `newpass123`. The actual seeded credentials (`db/migrations/000002_seed_default_iam.up.sql`) are `admin@gmail.com` / `admin123`. Verified live: the wrong credentials get `401`, the right ones get `200`. Only `backend/qa_test.sh` uses the correct credentials.
  - `TestHRLeaveStateLogic` (`backend/tests/business_logic_test.go:131-137`) converts a leave ID to a URL path via `string(rune('0' + leaveID))`, which only works for single-digit IDs and explicitly `t.Fatalf`s otherwise — broken for any reasonably-used database.
  - The new SEC-03 rate limiting (5 req/min/IP on `/iam/verify-pin`) trips itself when the test suite calls `getPINToken` repeatedly across `TestGhostModeLogic`, `TestHRLeaveStateLogic`, and every fuzz iteration — a genuine interaction bug between the security fix and the unmaintained tests.
  - There are **zero unit test files anywhere under `backend/internal/`** — every existing Go test is a live-integration test requiring a running docker-compose stack, not a unit test.
- `backend/scripts/gen_postman.sh` hardcodes an absolute Linux path (`/home/prateek/Documents/...`) and won't run unmodified on this machine.
- `backend/qa_test.sh` (283-line bash smoke test) has correct credentials and looks functional as a smoke test.

See [04-testing-strategy.md](04-testing-strategy.md) for recommendations.

## Clean bill of health

- **No SQL injection anywhere.** Every dynamic query across `crm/repository`, `hr/repository`, `logistics/repository` uses parameterized `$N` placeholders for values; only static literal fragments or placeholder indices are string-built.
- **No shared-channel AMQP concurrency race remains** — the BUG-B07 fix (channel-per-publish) is correctly implemented everywhere.
- `.env` secrets have never been committed to git history at any point (verified directly with `git log --all -- .env`), and `.env` is correctly gitignored.
