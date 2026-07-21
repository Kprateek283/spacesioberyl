# Backend — Problems & Bugs

Audit date: 2026-07-20 · Branch `dev` @ `a71d86f` · Go 1.25 / chi / pgx / Redis / RabbitMQ / MinIO

`go build ./...` and `go vet ./...` are both clean. Everything below is a logic,
security, or operational defect that compiles fine.

---

## Remediation status

All 32 items are resolved, across five waves on `dev` (plus a follow-up). Each
P0/P1 landed with a regression test that fails before its fix.

| Items | Status | Where |
|---|---|---|
| 1, 2, 5, 13, 32 | Fixed | wave 1 — *stop the bleeding* |
| 4, 6, 7, 8, 9, 10, 11, 21, 22, 24 | Fixed | wave 2 — *auth correctness* |
| 12, 14, 16, 17, 18, 19, 23, 31 | Fixed | wave 3 — *data integrity & ops* |
| 15 | Fixed | ships alone — money → int64 paise |
| 3 | Fixed | wave 4 — `docs/Ghost-mode.md` + contract tests |
| 20, 25, 28, 29, 30 | Fixed | wave 4 — *hygiene* |
| 26, 27 | No-op | already satisfied (26 tidy clean; 27 moot — RealIP removed by #4) |
| 30 (real pagination), 32 (root cause) | Fixed | wave-4 follow-up — paged envelope; BFF delegates to repositories |

Notes on deliberate ceilings:
- **#28** — the `accounts` role can view the expense ledger provisionally
  (owner's call), marked in a code comment; tighten later if needed.
- **#30** — paged response is `{items,total,limit,offset}` (default 10, cap
  200); the pipeline kanban keeps a fixed upper bound rather than paging.
- **#32 root cause** — the BFF now delegates the cash-bearing reads (quotations,
  order) to the owning repositories so the ghost-mode filter lives in one place.
  POs/installation stay inline (order-scoped, not cash surfaces).

---

## Found during remediation

### 33. NULL `installer_advance_amount` / `installer_final_amount` crash the installation scan
`installer_advance_amount` and `installer_final_amount` are non-nullable `int64`
in `execModels.Installation`, but the columns are nullable (an unpaid installer
has no final amount). Any installation row with a NULL in these columns fails to
scan — `cannot scan NULL into *int64`. Surfaced when the BFF's #32 refactor
stopped swallowing the installation scan error (previously a NULL silently
dropped the whole `job` from the response).

Fixed for the BFF path via `COALESCE(..., 0)` in `GetProjectDetails`. The same
raw scan still exists in `ExecutionRepository` (`GetByID`, `ListJobs`,
`GetMyJobs`, `CreateInstallation` RETURNING) and will crash on a NULL there too.
The columns default to 0, so only an explicit NULL (as in `dev_seed.sql`
installation 1) triggers it. Proper fix: `COALESCE` in those queries or make the
fields `*int64`. Not fixed — out of the #32 scope.

---

## P0 — Critical

### 1. The entire BFF module is unauthenticated
`internal/bff/handler.go:152-166`

```go
func RegisterRoutes(r chi.Router, h *BFFHandler) {
	// Note: Authentication middleware (JWT verification) should ideally wrap these routes
	r.Route("/api/v1/projects", func(r chi.Router) {
		r.Get("/pipeline", h.GetPipeline)
		r.Get("/{id}/details", h.GetProjectDetails)
		r.Post("/{id}/docs", h.UploadProjectDocument)
	})
	r.Route("/api/v1/workspace", func(r chi.Router) { ... })
}
```

No `middleware.RequireAuth`. Five endpoints are open to anyone who can reach the
port. `GET /api/v1/projects/pipeline` returns every lead with its approved
quotation value; `GET /api/v1/projects/{id}/details` returns orders, purchase
orders, installer prices, advance/final amounts and client sign-off URLs.

**Fix:** wrap both routes in `r.Use(middleware.RequireAuth)`, same as every other module.

### 2. `userID` is hardcoded to 1 in three BFF handlers
`internal/bff/handler.go:99`, `:117`, `:135`

```go
// NOTE: Hardcoding uploaderID to 1 (Admin/QA) since JWT middleware is temporarily bypassed for BFF.
uploaderID := 1
```

`GetActionItems` and `GetPersonalTimeline` return user 1's data to every caller,
and every uploaded document is attributed to user 1. The audit trail on
`project_documents.uploaded_by` is worthless. Follows directly from #1 — fixing
the middleware requires replacing these with `claims.UserID`.

### 3. Ghost Mode semantics are inverted between backend and frontend
`internal/crm/repository/quotation_repo.go:89`, `internal/crm/service/quotation_svc.go:31`

Backend contract is unambiguous — `ghost_mode == true` means cash is **visible**:

```go
if !ghostMode { query += " AND payment_term_type != 'cash'" }   // hide cash when NOT ghost
if req.PaymentTermType == "cash" && !middleware.GetGhostMode(ctx) {
	return nil, errors.New("cash payment terms require ghost mode to be enabled")
}
```

The Flutter client implements the opposite (see frontend report #2). The
backend is self-consistent; the mismatch means the high-security PIN reveals
data server-side while the UI hides it, and the normal PIN shows cash input
fields whose submissions the server rejects with a 400.

### 4. Rate limiting is bypassable, defeating login and PIN brute-force protection
`internal/app/app.go:69` + `internal/iam/router.go:23,42`

`chimiddleware.RealIP` overwrites `r.RemoteAddr` from the `X-Forwarded-For` /
`X-Real-IP` headers unconditionally, with no trusted-proxy allowlist. There is
no proxy in `docker-compose.yml` stripping those headers, so a client sets them
directly. `httprate.LimitByIP(5, 1*time.Minute)` then buckets on attacker-controlled
input — rotate the header per request and the limit never triggers.

That reduces the 4-digit normal PIN (10k combinations) and the 6-digit
high-security PIN (1M) to a straight online brute force, and the
high-security PIN mints ghost-mode tokens.

**Fix:** only apply `RealIP` when the request arrives from a known proxy CIDR,
or drop it and rate-limit on `RemoteAddr`. Add a per-user (not per-IP) failed
attempt counter with lockout for `/login` and `/iam/verify-pin`.

### 5. No JWT secret validation at boot
`internal/config/config.go:40`, `cmd/api/main.go:57`

```go
JWTSecret: getEnv("JWT_SECRET", ""),
...
os.Setenv("JWT_SECRET", cfg.JWTSecret)   // round-tripped back through the env for the middleware
```

If `JWT_SECRET` is unset the app starts happily and signs every token with an
empty HMAC key. Anyone can forge a `super_admin` + `ghost_mode:true` token.
There is no startup check anywhere.

**Fix:** `log.Fatal` in `main` if `cfg.JWTSecret` is under ~32 bytes. Also pass
the secret into `middleware.RequireAuth` as a parameter instead of laundering
it through `os.Setenv` — the round-trip exists only because the middleware
reads `os.Getenv("JWT_SECRET")` at `internal/middleware/auth.go:46`.

---

## P1 — High

### 6. Token revocation fails open when Redis is unavailable
`internal/middleware/auth.go:59`

```go
isBlacklisted, _ := cache.Client.Exists(r.Context(), "blacklist:"+tokenString).Result()
if isBlacklisted > 0 { ... }
```

The error is discarded. A Redis outage makes `isBlacklisted` 0 and every revoked
token valid again. Security checks should fail closed — return 503 on a Redis error.

### 7. Logout does not revoke the refresh token
`internal/iam/service/iam_service.go:288-292`

Only the access token is blacklisted, for 1 hour. The 30-day refresh token is
untouched, so a client (or an attacker holding a stolen token) can call
`/api/v1/refresh` immediately after logout and get a fresh session. Logout is
cosmetic.

**Fix:** blacklist the refresh token too (TTL = its remaining lifetime), or move
to a server-side session/refresh-token table.

### 8. No refresh token rotation or reuse detection
`internal/iam/service/iam_service.go:246-285`

`RefreshToken` mints a new pair but never invalidates the presented token — it
stays valid for its full 30 days and can be replayed indefinitely. Combined
with #7 there is no way to terminate a compromised session short of
deactivating the account.

Also, `RefreshToken` never checks the blacklist, so even an explicitly revoked
refresh token is accepted.

### 9. `validate:` struct tags are decorative — no validator is installed
`internal/iam/dto/iam_dto.go` (and every other `dto` package)

```go
Password string `json:"password" validate:"required,min=8"`
Email    string `json:"email" validate:"required,email"`
```

`go.mod` contains no `go-playground/validator` or equivalent, and no handler
calls `validate.Struct`. Every one of these tags is inert. Concretely:

- `POST /api/v1/users` accepts a 1-character password and a malformed email.
- `POST /api/v1/password/reset` accepts any-length new password.
- `PATCH /api/v1/users/me/password` likewise.

Only PIN format is genuinely validated (`iam_service.go:107-112`, via regexp).

**Fix:** add the dependency and validate in each handler, or write explicit
checks in the service layer. Either way the tags currently lie about the contract.

### 10. Privilege escalation — an `admin` can create a `super_admin`
`internal/iam/handler/iam_handler.go:57-59`

```go
// In a real app, you'd extract the caller's role from the JWT Context here
// to ensure an 'admin' isn't trying to create a 'super_admin'.
```

The check is documented as missing and is missing. `RequireRole("admin", "super_admin")`
gates the route, then `CreateUser` accepts any `role` string the caller sends. Any
admin can mint a super_admin account and take over the tenant.

### 11. Attendance geofence is trivially spoofable
`internal/hr/handler/attendance_handler.go:157-177`

`extractClientIP` trusts `X-Forwarded-For` then `X-Real-Ip` before falling back
to `RemoteAddr`. Sending `X-Forwarded-For: <office IP>` marks any remote check-in
as on-network, bypassing the override-request workflow entirely. Same root cause
as #4.

Compounding it, `OFFICE_IP` defaults to `"0.0.0.0"` (`config.go:42`), which
`isOfficeNetwork` treats as "accept every IP" (`attendance_svc.go:75-78`). A
deployment that forgets the variable silently disables the check with no warning log.

### 12. Public MinIO bucket exposes quotation PDFs and receipts
`internal/storage/minio.go:49-51`

```go
// Build the public URL (works because minio-setup sets the bucket to public)
url := fmt.Sprintf("%s/%s/%s", PublicURL, DefaultBucket, objectName)
```

Every quotation PDF, expense receipt, site photo and client signature is
readable by URL with no authentication. Object names are predictable
(`quotations/123/quote.pdf`), so enumeration is easy.

**Fix:** keep the bucket private and hand out presigned URLs with short expiry.

### 13. Unauthenticated POC endpoint publishes to RabbitMQ and writes Redis
`internal/app/app.go:96`, `:100-118`

`POST /api/v1/test/ping` is registered outside every auth group. It writes a
Redis key and publishes to `sync_queue` on each call — an unauthenticated queue-
flood and cache-write primitive. Delete it, or move it behind auth and a build tag.

### 14. RabbitMQ messages are non-persistent — events are lost on broker restart
`internal/broker/rabbitmq.go:63-66`

```go
err = ch.PublishWithContext(ctx, "", queueName, false, false, amqp.Publishing{
	ContentType: "application/json",
	Body:        body,
})
```

Queues are declared durable (`:41`) but the messages are not — no
`DeliveryMode: amqp.Persistent`. A broker restart drops every queued
`quote_approved`, `installation_signoff` and WhatsApp notification. The durable
queue gives a false sense of safety.

There is also no reconnection logic: if the connection drops, `Conn.Channel()`
fails for the remaining process lifetime and every publish errors until restart.

---

## P2 — Medium

### 15. Money is `float64` everywhere
`internal/crm/model/crm_models.go:42,43,61,62`, `internal/hr/model/hr_models.go:28`,
`internal/execution/model/execution_models.go:21,26,27,64`,
`internal/logistics/model/logistics_models.go:39`

`TotalAmount`, `TaxAmount`, `UnitPrice`, `InstallerAdvanceAmount`, expense
`Amount` — all binary floating point. Quotation totals are computed by
summing line items and applying a tax rate (`quotation_svc.go`), so rounding
error accumulates and the PDF total can disagree with the ledger by paise.

**Fix:** integer minor units (paise) or `shopspring/decimal`, with matching
`NUMERIC` columns.

### 16. Silently swallowed query errors in BFF project details
`internal/bff/service.go:155`, `:175`

```go
poRows, _ := s.db.Query(gCtx, poQuery, o.ID)
updRows, _ := s.db.Query(gCtx, updQuery, i.ID)
```

A failing query yields an empty list, and the response looks like "this project
has no purchase orders / no installation updates". Silent data loss presented as
valid data — worse than a 500.

### 17. `http.ListenAndServe` with no timeouts and no graceful shutdown
`internal/app/app.go:200`, `cmd/api/main.go:60-63`

No `ReadTimeout`, `WriteTimeout`, `IdleTimeout` or `ReadHeaderTimeout` — the
server is Slowloris-exposed and a stalled client holds a goroutine indefinitely.
No signal handling either, so a deploy drops in-flight requests and the
`defer dbPool.Close()` / broker closes in `main` never run.

**Fix:** an explicit `&http.Server{...}` with timeouts plus
`signal.NotifyContext` + `srv.Shutdown(ctx)`.

### 18. Nil-pointer panic on upload when MinIO init failed
`cmd/api/main.go:51-54` → `internal/storage/minio.go:42`

MinIO failure is deliberately non-fatal, but `UploadFile` calls
`Client.PutObject` with no nil guard. Any upload after a failed init panics;
`chimiddleware.Recoverer` converts it to an opaque 500. Either guard `Client`
and return a typed "storage unavailable" error, or make init fatal.

### 19. No request body size limit
All handlers use bare `json.NewDecoder(r.Body).Decode(&req)`. Only the BFF
multipart upload caps size (10 MB, `bff/handler.go:75`). A large JSON body is
read entirely into memory. Wrap with `http.MaxBytesReader`.

### 20. CORS prefix match allows lookalike hosts
`internal/middleware/cors.go:52`

```go
return strings.HasPrefix(host, "localhost")
```

Matches `localhost.attacker.com`. The exact-match map above it already covers
the intended dev origins — this fallback only adds risk. Delete it, or compare
against `"localhost"` exactly.

### 21. Password reset OTP has no attempt limit
`internal/iam/service/iam_service.go:342-353`, `internal/iam/router.go:25-26`

`/password/forgot` and `/password/reset` carry no `httprate` limiter (unlike
`/login`), and `ResetPassword` does not count failures. A 6-digit OTP with a
15-minute window and unlimited guesses is brute-forceable. Add a limiter and
delete the OTP after N failed attempts.

### 22. OTP is printed to stdout unconditionally
`internal/iam/service/iam_service.go:336`

```go
fmt.Printf("🔒 OTP Generated for %s: %s\n", user.Email, otp)
```

No environment guard. In production this writes password-reset codes into the
container log, where anyone with log access can hijack any account. At minimum
gate on an `APP_ENV != "production"` check; better, wire the real email/SMS sender.

### 23. Modulo bias in OTP generation
`internal/iam/service/iam_service.go:322-324`

24 random bits (16,777,216) reduced `% 1000000` leaves the first 777,216 codes
~1.8x more likely than the rest. Minor, but free to fix with
`rand.Int(rand.Reader, big.NewInt(1000000))`.

### 24. Login is vulnerable to user enumeration by timing
`internal/iam/service/iam_service.go:44-57`

A missing email returns before any bcrypt work; an existing email pays the full
cost-10 hash. The response strings are identical but the timing differs by
~50-100 ms. Run a dummy `CheckPasswordHash` against a fixed hash on the
not-found path.

### 25. Docker-shaped credentials as code defaults
`internal/config/config.go:37-46`

`postgres://admin:securepassword@system_db:5432/...`, MinIO `admin` /
`securepassword`. Defaults that look production-plausible get shipped when an
env var is missing. Prefer failing loudly over defaulting for credentials.

---

## P3 — Low / hygiene

### 26. `go.mod` is stale
`github.com/go-chi/httprate` is marked `// indirect` but is imported directly by
`internal/iam/router.go`. Run `go mod tidy`.

### 27. `RealIP` registered after `Logger`
`internal/app/app.go:67-69` — the request logger records the proxy address
rather than the client address, because it runs before `RealIP` rewrites it.
Swap the two.

### 28. Comment/code mismatch on expense permissions
`internal/hr/router.go:40-42` — the comment says "Admin / Super Admin / Accounts
can view the ledger" but the code is `RequireRole("admin", "super_admin")`. The
accounts role is silently excluded.

### 29. TOCTOU in leave editing
`internal/hr/service/leave_svc.go:71-80` reads the leave and checks ownership,
then `repo.UserEdit` re-queries by id. The `AND status = 'pending'` in the
UPDATE covers the status race, but the ownership check is not re-asserted in the
WHERE clause. Add `AND user_id = $n` and drop the pre-read.

### 30. No pagination anywhere
`GetPipeline` (`bff/service.go:28`), `ListUsers`, `ListAll` for leaves,
attendance, expenses and leads all return unbounded result sets. Fine at current
scale, a wall at a few thousand rows.

### 31. Uploaded filenames are not sanitised
`internal/bff/handler.go:99-101` passes `fileHeader.Filename` straight into the
object name. No extension allowlist, no content-type check, no path-segment
stripping. Combined with the public bucket (#12), a user-supplied `.html` is
served from your storage domain.

---

## What is done well

- **No SQL injection.** Every dynamically assembled query (`lead_repo.go:50-59`,
  `expense_repo.go:50-64`, `leave_repo.go:92-147`, `attendance_repo.go:95-122`)
  appends `$N` placeholder positions, never interpolated values.
- Passwords and PINs use bcrypt correctly, with `CompareHashAndPassword` rather
  than a manual comparison.
- `GetGhostMode` fails closed — a missing claim returns `false` (cash hidden).
- Refresh tokens are re-checked against the DB for `is_active` on every refresh
  (`iam_service.go:264-267`), so deactivation propagates within the access-token TTL.
- Access tokens are rejected where a refresh token is presented (`auth.go:66`).
- Clean layering: router → handler → service → repository, consistently applied
  across all six modules.

---

## Found during remediation

### 32. The BFF bypasses every ghost-mode cash filter
`internal/bff/service.go:37`, `:126`, `:145`, `:273` (pre-fix line numbers)

Found while authenticating the BFF (#1). The BFF re-implements queries that
already exist in `QuotationRepository.ListByLead` and
`LogisticsRepository.ListOrders` — and in re-implementing them, drops the
`payment_term_type != 'cash'` filter those repositories apply. Four surfaces
returned cash-bearing data to any caller regardless of ghost mode:

- `GetPipeline` — approved quotation `total_amount`, no filter
- `GetProjectDetails` — quotations including `payment_term_type`, no filter
- `GetProjectDetails` — orders including `payment_term_type`, no filter
- `GetPersonalTimeline` — quotations by `created_by`, no filter

This is exactly the enforcement gap the plan's #3 audit anticipated: "an
inconsistently applied filter is nearly as bad as an inverted one." It was
masked by #1 — while the module was unauthenticated there was no ghost-mode
claim to consult at all.

Note that only a `super_admin` can ever hold a ghost-mode token:
`IAMService.SetupPins` (`iam_service.go:95`) refuses to store PINs for any
other role, and ghost mode is only minted by `VerifyPin` against the
high-security PIN. So the practical impact was that **staff and admins could
read cash quotation values** through the BFF that the CRM module correctly
hid from them.

**Fixed during wave 1** at the product owner's direction (cash is
super_admin-only), via a shared `cashFilter` helper applied to all four sites.
The underlying duplication — the BFF hand-rolling queries that repositories
already own — is not fixed and will re-create this class of bug.
