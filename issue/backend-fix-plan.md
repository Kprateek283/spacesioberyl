# Backend — Remediation Plan

Companion to `backend-bugs.md`. No code, sequencing and approach only.
Numbering matches the bug report exactly.

**Ruling on #3 (Ghost Mode):** the backend is **correct** and is the canonical
contract — `ghost_mode == true` means cash is visible. No backend change. The
Flutter client changes to match. See `frontend-fix-plan.md` item 2. The only
backend work is to write the contract down so it cannot drift again.

---

## Sequencing

Four waves. Do not reorder waves 1 and 2 — several wave-2 items depend on the
auth plumbing landing first.

| Wave | Contains | Gate to exit |
|---|---|---|
| 1. Stop the bleeding | 1, 2, 5, 13 | Nothing reachable without a valid token |
| 2. Auth correctness | 4, 6, 7, 8, 9, 10, 11, 21, 22, 24 | Session lifecycle and RBAC are sound |
| 3. Data integrity & ops | 12, 14, 15, 16, 17, 18, 19, 23, 31 | Safe to run unattended |
| 4. Hygiene | 20, 25, 26, 27, 28, 29, 30, plus the #3 doc | Backlog |

Wave 1 is a single focused PR. Do not bundle it with anything else — it needs to
be reviewable in one sitting and deployable immediately.

---

## Wave 1 — Stop the bleeding

### 1. Authenticate the BFF module
Wrap both `/api/v1/projects` and `/api/v1/workspace` route groups in the same
`RequireAuth` middleware every other module uses. Then decide the authorization
tier for each of the five endpoints — pipeline and project details expose
financial aggregates, so they likely warrant a role check beyond
"any authenticated user". Confirm with the product owner which roles should see
the pipeline before choosing.

While in the file, delete the "should ideally wrap these routes" comment — a
comment describing a missing control is worse than nothing, because it reads as
a decision rather than a gap.

**Verification:** an unauthenticated request to each of the five endpoints must
return 401. Add this as a test, not a manual curl — it is the exact regression
that will recur.

### 2. Replace the hardcoded `userID`
Once #1 lands, the claims are in the request context. Pull `UserID` from them in
`GetActionItems`, `GetPersonalTimeline` and `UploadProjectDocument`, exactly as
the IAM and HR handlers already do.

Then check the data written while the bug was live: every row in
`project_documents` with `uploaded_by = 1` is suspect. If the BFF upload route
has been used outside QA, those attributions are wrong and cannot be
reconstructed — decide whether to null them out or annotate them, but do not
leave them silently wrong.

**Verification:** two different users hitting `/workspace/action-items` get
different payloads.

### 5. Fail fast on a missing JWT secret
Validate in `config.Load` or at the top of `main`: if the secret is empty or
implausibly short, log the reason and exit non-zero. A CRM that boots with
forgeable tokens is worse than one that does not boot.

Separately, remove the `os.Setenv("JWT_SECRET", ...)` round-trip in `main`. The
middleware reads the secret from the environment because it has no other way to
receive it; give `RequireAuth` the secret as a parameter (a middleware
constructor that closes over it) and the global mutable env dependency
disappears. This also makes the middleware testable without environment
manipulation.

Pick a minimum length deliberately — HS256 keys below 32 bytes weaken the
signature meaningfully.

**Verification:** starting the API with `JWT_SECRET` unset exits with a clear
message. Starting it with a short secret does too.

### 13. Delete the POC ping endpoint
`POST /api/v1/test/ping` has no production purpose. Delete it and its handler.
If a queue/cache smoke test is genuinely wanted, rebuild it behind
`RequireRole("super_admin")` — but prefer a proper readiness probe that checks
dependency health without writing to them.

Keep `GET /ping` — an unauthenticated health check returning only `{"status":"ok"}`
is correct and leaks nothing.

---

## Wave 2 — Auth correctness

### 4. Fix client IP determination
This is the root cause for both #4 and #11, so fix it once, in one place.

The `RealIP` middleware currently trusts `X-Forwarded-For` from any source. Two
viable approaches:

- **If a reverse proxy will front the API:** configure the proxy to overwrite
  (not append to) the forwarded headers, and configure the app to trust them
  only when the immediate peer is in the proxy's CIDR.
- **If the API is directly exposed** (the current `docker-compose.yml` shape):
  remove `RealIP` entirely and use the socket peer address. It cannot be spoofed.

Decide which deployment topology is real before choosing — guessing here
produces either a spoofable header or broken rate limiting behind a load
balancer.

Then add a genuine per-account failed-attempt counter for `/login` and
`/iam/verify-pin`, keyed on the user, with lockout and backoff. IP-based limiting
is a coarse first layer; it cannot protect a specific account from a distributed
attempt, and the 4-digit PIN needs that protection.

**Verification:** a test that sends 20 login attempts with rotating
`X-Forwarded-For` values must see them rate limited.

### 6. Fail closed on Redis errors in the auth path
The blacklist check discards its error. Handle it: on a Redis error, reject the
request (503 or 401 — 503 is more honest) rather than treating the token as
valid.

Audit the other Redis call sites in the auth flow for the same pattern while you
are there. The password-reset OTP lookup already handles its error correctly;
confirm nothing else swallows one.

Accept the tradeoff explicitly: Redis becomes a hard dependency for serving
authenticated traffic. That is the correct posture for a revocation check, but
it raises the operational bar — pair it with a Redis health check in the
readiness probe so the failure is visible before it causes 503s.

### 7 + 8. Rebuild the session lifecycle
These two are one design problem, not two bugs. Solve them together.

The current model — stateless JWTs plus a 1-hour access-token blacklist — cannot
express "this session is over", because the 30-day refresh token is never
revoked and is replayable indefinitely.

Choose one of two coherent designs:

- **Server-side refresh tokens.** Persist a row per issued refresh token
  (user, jti, issued, expires, revoked). Refresh looks it up, rotates it, and
  marks the old one used. Logout revokes the row. Reusing a rotated token is a
  strong theft signal — revoke the whole family and force re-login. This is the
  more robust option and is what the "PIN unlock" UX implies.
- **Blacklist the refresh token too.** Cheaper: on logout, blacklist the refresh
  token with a TTL matching its remaining lifetime, and check the blacklist in
  the refresh path (currently it does not). Rotation still needs the old token
  invalidated on each refresh, which pushes you most of the way to option 1
  anyway.

Recommend option 1. Option 2 leaves you unable to answer "which sessions are
active for this user", which a CRM with a ghost-mode feature will eventually need.

Either way: the refresh path must check revocation, which it does not today.

**Verification:** after logout, the refresh token is rejected. After a refresh,
the previous refresh token is rejected.

### 9. Make the `validate` tags real
Add a validation library and invoke it in every handler after decoding, or
delete the tags and validate explicitly in the services. Do not leave the
current state, where the tags document a contract that is not enforced — that is
actively misleading to anyone reading the DTOs.

Recommend adding the library: the tags already express the intent correctly, the
DTOs are the right place for it, and the work is mechanical.

Priority order for the rules that are currently unenforced: password minimum
length on user creation, password reset and password change; email format
everywhere it is claimed. Note that adding a password minimum will reject
existing weak passwords on their next change — that is intended, but decide
whether to force a reset for accounts already below the bar.

### 10. Close the privilege escalation in user creation
Read the caller's role from the claims and enforce a hierarchy: an `admin` may
not create or promote to `super_admin`. Only `super_admin` can mint another
`super_admin`.

Then audit existing accounts — if any `super_admin` was created by an `admin`
while this was open, that is an active compromise, not a historical one.

Apply the same rule to any future role-change endpoint. Write the hierarchy down
in one place rather than duplicating the comparison across handlers.

### 11. Attendance geofence
Mostly resolved by fixing #4 — once the client IP is trustworthy, the
`X-Forwarded-For` spoof closes. Remove the handler's own `extractClientIP`
helper and use the single trusted source, so there is one definition of "client
IP" in the codebase rather than two that disagree.

Separately, the `OFFICE_IP` default of `0.0.0.0` silently disables the check.
Either require the variable explicitly (fail at boot without it), or keep the
permissive default but log a loud warning at startup that the geofence is
disabled. Silent is the only unacceptable option.

Consider whether IP is the right signal at all — a staff member on office WiFi
via VPN, or on a guest network, will fail it. The override-request workflow
exists to handle that, so the current design is defensible; just confirm the
override queue is actually being triaged by admins in practice.

### 21 + 22. Password reset hardening
Three changes, all small:

- Add rate limiting to `/password/forgot` and `/password/reset` — they currently
  have none while `/login` does, which is inconsistent and leaves the OTP
  brute-forceable.
- Count failed OTP attempts and invalidate the OTP after a small number.
  A 6-digit code with unlimited guesses inside a 15-minute window is not a
  meaningful control.
- Remove the unconditional OTP print to stdout. Wire the real email/SMS sender.
  If that integration is not ready, gate the print behind an explicit
  non-production environment check — but treat the missing sender as the actual
  blocker, because until it exists the reset flow is not usable by real users
  anyway.

### 24. Constant-time login
Run a dummy password comparison against a fixed hash on the user-not-found path,
so both branches pay the same bcrypt cost. Low severity, near-zero effort, and
it closes the enumeration channel that the deliberately-vague error strings were
already trying to close.

---

## Wave 3 — Data integrity and operations

### 12 + 31. Object storage
Make the bucket private and serve files through presigned URLs with a short
expiry. This is one change with two beneficiaries: it closes the public-read
exposure (#12) and it defuses the unsanitised-filename problem (#31), since
files are no longer served from a browsable public path.

Still fix the filename handling: strip path segments, enforce an extension and
content-type allowlist, and generate the stored object name server-side rather
than trusting the client's filename. Do not rely on the presigned URL alone.

Consider what happens to already-uploaded files when the bucket flips to
private — any URL persisted in the database becomes dead. Plan a migration that
rewrites stored URLs to keys, and generates presigned URLs at read time.

### 14. RabbitMQ durability and reconnection
Mark published messages persistent. The queues are already durable, so this is
the missing half — currently a broker restart loses quote approvals and
sign-offs while appearing safe.

Add reconnection handling: the current code fails permanently once the
connection drops and only recovers on process restart. Use the library's close
notifications to rebuild the connection and channel.

Then decide the delivery guarantee you actually want. Persistence plus
reconnection gets you at-least-once *if* publishes are confirmed and failures
are retried; without publisher confirms, a publish can still be silently lost.
For quote approvals and installation sign-offs — both financially meaningful —
confirms are worth the complexity. Add a dead-letter queue so poison messages
are visible rather than redelivered forever.

### 15. Money representation
The largest mechanical change in this plan. Migrate all monetary fields off
`float64` to either integer minor units or a decimal type, with matching
`NUMERIC` columns in Postgres.

Sequence it carefully:
1. Change the database columns first, with a migration that converts existing
   values and is reversible.
2. Change the models and repositories.
3. Change the calculation sites — quotation line-item totals and tax are where
   error compounds today.
4. Check the PDF generation path and any API response formatting, since the JSON
   shape may change for clients.

Coordinate with the frontend: if the wire format changes from a JSON number to
a string or an integer count of paise, the Flutter parsing changes too. Agree the
representation before either side starts.

Do this as its own PR with no other changes in it.

### 16. Stop swallowing query errors in the BFF
The two discarded errors in project details turn a database failure into
"this project has no purchase orders". Handle them: either fail the request or
return an explicit partial-result indicator. Silently presenting incomplete
financial data as complete is the worst available outcome.

Audit the rest of the BFF service for the same pattern while in the file.

### 17. Server timeouts and graceful shutdown
Replace the bare `ListenAndServe` with an explicit server carrying read, write,
idle and read-header timeouts. Add signal handling and a bounded shutdown so
in-flight requests drain and the deferred pool and broker closes in `main`
actually run — today they never execute.

Choose the write timeout with the slowest legitimate endpoint in mind: PDF
generation and file upload are the candidates. Measure before picking a number.

### 18. Guard the MinIO client
Uploads panic when initialization failed, because the failure is non-fatal but
the client is never nil-checked. Either make initialization fatal at boot, or
guard the client and return a clear "storage unavailable" error.

Prefer making it fatal. The current non-fatal choice trades a loud startup
failure for a confusing 500 at an arbitrary later moment, which is a bad trade.

### 19. Bound request bodies
Wrap JSON decoding with a size limit across all handlers. The BFF multipart
upload already caps at 10 MB; everything else is unbounded. Apply it as
middleware rather than per-handler so new handlers inherit it.

### 23. OTP randomness
Replace the modulo reduction with rejection-free random-integer generation in
the target range. Trivial change; do it when touching #21/#22 rather than as its
own PR.

---

## Wave 4 — Hygiene and consistency

### 3. Document the Ghost Mode contract (backend is correct — no logic change)
The backend is the source of truth: `ghost_mode == true` means cash is visible.
The inversion is entirely on the client.

The backend work is prevention, not correction:

- Write the contract in one place — a short section in `docs/Ghost-mode.md`
  stating the direction unambiguously, with the enforcement points listed
  (quotation creation, quotation listing, quotation fetch, logistics).
- Add tests that pin the direction in both states: a ghost-mode context sees
  cash quotations and may create them; a non-ghost context sees neither. These
  tests are what stop a future "fix" from flipping the backend to match a
  broken client.
- Audit for enforcement gaps. Ghost mode is currently checked in only four
  places. Confirm no other cash-bearing surface — HR expenses, contractor
  payments, purchase orders — should be filtering and is not. That gap, if it
  exists, is a real bug hiding behind a correct implementation.

The last point is the one worth real attention: an inconsistently applied filter
is nearly as bad as an inverted one.

### 20. CORS prefix match
Delete the `HasPrefix(host, "localhost")` fallback — the exact-match set above
it already covers the intended origins, and the prefix match additionally
allows lookalike hosts. Removing code is the whole fix.

Also decide how production origins will be configured, since the current list is
development-only and will need to come from configuration.

### 25. Credential defaults
Remove plausible-looking credential defaults from config. For anything that is a
secret — database URL, MinIO keys, JWT secret — fail at boot when unset rather
than falling back. Non-secret values (port, bucket name) can keep defaults.
This is the same principle as #5, applied consistently.

### 26. `go mod tidy`
`httprate` is marked indirect but imported directly. One command.

### 27. Middleware ordering
Move `RealIP` before `Logger` so logs record the client address rather than the
proxy. Only meaningful if #4 keeps `RealIP` at all — if #4 removes it, this item
disappears.

### 28. Expense permission mismatch
The comment says accounts can view the ledger; the code excludes that role.
Determine which is correct and align them. If accounts should have access, this
is a functional bug affecting real users, not a comment fix — check with the
product owner rather than assuming the code is right.

### 29. Leave edit TOCTOU
Fold the ownership check into the UPDATE's WHERE clause alongside the existing
status check, and drop the separate pre-read. Shorter and race-free. Preserve
the distinct error messages users see today if they are relied upon.

### 30. Pagination
Add limit/offset (or cursor) to the unbounded list endpoints: pipeline, users,
leaves, attendance, expenses, leads. Not urgent at current data volume, but it
is much cheaper to add before clients depend on receiving everything in one
response. Coordinate with the frontend, since it will need to handle paging.

---

## Cross-cutting

**Testing.** The existing `backend/tests` covers fuzz, business logic and BFF.
Every P0 and P1 above should land with a test that fails before the fix. Highest
value: an unauthenticated-access test across the full route table, which would
have caught #1 and #13 immediately and will catch the next one.

**A route inventory test.** The BFF gap existed because nothing enumerated the
routes and asserted their protection level. A single test that walks the router
and asserts each path's expected auth tier turns this whole class of bug into a
compile-time-ish failure. Build it during wave 1 — it is the highest-leverage
item in this document.

**Secrets.** #5, #22 and #25 are the same underlying problem: secrets have
permissive fallbacks and one is printed to logs. Address them as one theme with
one rule — no secret has a default, and no secret is logged.
