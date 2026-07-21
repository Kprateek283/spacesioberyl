# Frontend Handoff — Backend Remediation

Backend remediation (waves 1–4 + #15 + #32) is complete and on `dev`. This
document tells the Flutter team **what changed on the wire** and **which of your
own known issues are now unblocked or need to move together**.

Read it alongside:
- `backend-bugs.md` — the resolved backend items (statuses at the top).
- `frontend-bugs.md` / `frontend-fix-plan.md` — your existing issues; referenced by number here as **FE#n**.
- `backend/docs/Ghost-mode.md` — the canonical cash-visibility contract.

Legend: **BE#n** = backend issue, **FE#n** = frontend issue.

---

## 1. Breaking wire-format changes — you must adapt

These change JSON shapes. Nothing here is backward compatible; the client will
misbehave until updated.

### 1a. Money is now integer **paise**, not a decimal (BE#15)

Every monetary field is an `int64` count of paise (₹1 = 100). The JSON is a bare
integer — e.g. `27500000` means **₹2,75,000.00**.

- **Display:** divide by 100. `₹${(paise/100).toStringAsFixed(2)}`.
- **Input:** multiply by 100 and round to a whole integer before sending.
- **Not money, unchanged:** `tax_rate` is still a percentage float (e.g. `18`),
  and `quantity` is still a float. Do **not** ×100 these.

Affected response fields:

| Object | Paise fields |
|---|---|
| Quotation | `subtotal`, `tax_amount`, `total_amount` |
| Quotation line item | `unit_price`, `total_price` |
| Expense | `amount` |
| Purchase order | `total_amount` |
| Installer | `standard_rate` |
| Installation | `agreed_installer_price`, `installer_advance_amount`, `installer_final_amount` |
| Installer payment | `amount` |
| Installer ledger | `agreed_price`, `total_advance`, `total_final`, `total_paid`, `remaining_balance` |
| BFF pipeline card | `value` |
| BFF action item | `amount` |

Affected **request** bodies (send paise integers):
`line_items[].unit_price` (create quotation), `amount` (create expense),
`total_amount` (create PO), `standard_rate` (create installer),
`agreed_installer_price` (assign installer), `amount` (record installer payment).

### 1b. List endpoints return a paged envelope (BE#30)

Five list endpoints no longer return a bare array. They now return:

```json
{ "items": [ ... ], "total": 137, "limit": 10, "offset": 0 }
```

- Read `response.items`, not the top-level body.
- Query params: `?limit=<1..200>&offset=<n>`. **Default page size is 10**, hard cap 200.
- Endpoints: `GET /crm/leads`, `GET /users`, `GET /hr/leaves`, `GET /hr/attendance`, `GET /hr/expenses`.

**Unchanged (still bare arrays):** the "my/me" lists (`/hr/leaves/me`,
`/hr/attendance/me`, `/crm/followups/my-queue`, `/execution/jobs/my-tasks`,
`/logistics/dispatches/my-tasks`), plus vendors, installers, jobs, orders,
complaints. The BFF **pipeline** is still the grouped kanban shape (leads /
procurement / execution / completed) — internally capped at 200, no paging params.

### 1c. Files are private and auth-gated — no more public URLs (BE#12 / BE#31)

Uploads no longer return a public bucket URL. `POST /projects/{id}/docs` returns
`file_url` shaped like `/api/v1/files/<server-generated-key>`. Quotation PDFs use
the same path.

- **To display/download a file, GET that path with the `Authorization: Bearer`
  header** — it streams the bytes. A bare `<img src>` / browser fetch without the
  token gets 401.
- The old `https://mock.local/...` and public-bucket URLs are dead. Any stored
  record still holding one has no file behind it (see FE#3).
- Upload constraints: extension allowlist (`pdf, png, jpg, jpeg, webp`), the
  object key is generated server-side (your filename is ignored except its
  validated extension), body cap ~10 MB.

> **Coordination (FE#3):** you asked for a *generic* upload endpoint to replace
> `MockUploadService`. That does **not** exist yet — the only uploader is
> `POST /projects/{id}/docs` (project-scoped). If you need site-update photos /
> signatures / receipts uploaded, we need to agree and build a generic
> `POST /files` endpoint. Flag this and we'll add it.

---

## 2. Auth & session changes

### 2a. Refresh-token rotation + reuse detection (BE#7 / BE#8) — directly enables FE#5, FE#14

- `POST /login` and `POST /refresh` both return `AuthResponse` with **both**
  `access_token` and `refresh_token`. On refresh the `user` object is omitted.
- **Every `/refresh` rotates the refresh token.** You must overwrite stored
  `refresh_token` with the one in the response. The old one is now invalid.
- **Reusing a rotated/old refresh token revokes the entire token family** and
  forces re-login. Treat a 401 from `/refresh` as "session dead → clear storage →
  go to login".
- `POST /logout` now genuinely revokes server-side (fixes the FE#14 gap where the
  session stayed live). It requires a valid access token.
- Token TTLs: access **1 hour**, refresh **30 days**.

> **FE#5 (cold-start refresh):** now safe to implement. On startup, if the access
> token is expired but a refresh token exists, call `/refresh`, store the new
> pair, and proceed — only fall back to signed-out if `/refresh` returns 401.

### 2b. Rate limiting → expect 429 (BE#4 / BE#11)

`POST /login`, `POST /iam/verify-pin`, `POST /password/forgot`, and
`POST /password/reset` are limited to **5 requests/min per client IP**. Over that
returns **429**. Handle it explicitly (surface a "try again shortly" message +
backoff); do not treat 429 as bad credentials.

### 2c. Auth can now return 503 (BE#6)

The token-revocation check fails **closed**: if the backend's Redis is briefly
unreachable, an authenticated request returns **503**, not 200. Treat 503 on an
authed request as **transient/retryable** — do **not** sign the user out or drop
their session on a 503.

### 2d. PIN / Ghost-mode token (relates to FE#1, FE#2)

- `POST /iam/verify-pin` returns `{ "access_token": ..., "ghost_mode": <bool> }`.
  The high-security PIN mints an access token with `ghost_mode = true`.
- **Only `super_admin` can set up or verify a PIN.** `/iam/setup-pins` is
  `super_admin`-only, and `verify-pin` returns an error for any account with no
  PIN hash — which is every non-super-admin. This is the root of **FE#1** (the
  PIN lockout): the client gates the whole app on PIN, but the backend can only
  satisfy that for super_admin. **Recommended resolution (per the fix plan):**
  gate `sessionUnlocked` on `role == 'super_admin'`; everyone else is unlocked
  immediately. This is the intended design — PIN exists to toggle cash
  visibility, which is meaningless for roles that can never see cash.

---

## 3. Ghost Mode — the contract (BE#3) — reconciles FE#2

**The backend is canonical. `ghost_mode == true` means cash is VISIBLE.** The
client widgets (`GhostModeAware`, `GhostAwareCashText`, `GhostAwareCashField`)
are inverted (FE#2) and must flip: content currently hidden when `isGhostMode` is
true must be hidden when it is **false**.

- With the high-security PIN (ghost on) → cash quotations/orders are returned and
  should be shown.
- Without it (ghost off) → the API omits cash rows and reports `value: 0` for a
  cash-only project. Cash **input** fields must be absent so the user cannot build
  a request the backend rejects with *"cash payment terms require ghost mode"*.
- Only `super_admin` ever holds ghost mode (§2d).
- The full contract, enforcement points, and the tests that pin the direction are
  in `backend/docs/Ghost-mode.md`. **Do not re-invert the backend to match the
  client** — the client changes.

The BFF now applies this filter through the owning repositories (BE#32), so it is
consistent across the pipeline, project details, and personal timeline — all of
them honor ghost mode identically now.

---

## 4. Validation & RBAC

- **Passwords** (BE#9): create-user, change-password, and reset-password enforce
  **min 8 chars** → **400** on a short password. Email format is validated where
  claimed. Validate client-side to give a better message than the raw 400.
- **Role creation** (BE#10): an `admin` may **not** create or promote to
  `super_admin` → **403**. Only a `super_admin` can. Your role picker should hide
  `super_admin` for admin callers.
- **Expense ledger** (BE#28): `admin`, `super_admin`, **and `accounts`** may view
  `GET /hr/expenses` (provisional — may tighten later).
- **Leave edit** (BE#29): editing a leave that isn't yours or isn't `pending`
  returns **400** ("leave not found, not yours, or cannot be edited"). Same for
  cancel. No behavior change for the happy path.
- **BFF now requires auth** (BE#1): `/api/v1/projects/*` and
  `/api/v1/workspace/*` reject anonymous callers (401). Send the token — this
  also closes the FE#12 data-leak concern on `/home`.

---

## 5. Operational limits

- **Server timeouts** (BE#17): write timeout **60 s** (covers slow PDF/upload
  paths), read-header 5 s, idle 120 s. Set your Dio `receiveTimeout`/`sendTimeout`
  a little above 60 s so you don't abort a legitimately slow response (FE#6).
- **Request body cap** (BE#19): bodies over ~11 MB are rejected (4xx). Uploads are
  capped ~10 MB. Compress/limit media before sending.
- **CORS** (BE#20): exact-origin allow-list; production origins come from server
  config. If a new web origin needs access, it must be added to the backend
  `CORS_ALLOWED_ORIGINS` — tell us the origin.

---

## 6. Endpoint change quick-reference

| Endpoint | What changed |
|---|---|
| `POST /login` | Returns `access_token` + `refresh_token`; rate-limited (429) |
| `POST /refresh` | **Rotates** refresh token — store the new one; reuse → 401 + family revoke |
| `POST /logout` | Now revokes server-side |
| `POST /iam/verify-pin` | Rate-limited; response carries `ghost_mode`; super_admin-only |
| `POST /password/forgot` · `/password/reset` | Rate-limited; OTP has an attempt cap |
| `GET /crm/leads`, `/users`, `/hr/leaves`, `/hr/attendance`, `/hr/expenses` | Paged envelope `{items,total,limit,offset}`, default 10 |
| All quotation / expense / PO / installer / payment payloads | Money is int64 **paise** |
| `POST /projects/{id}/docs` | `file_url` = `/api/v1/files/<key>` (auth-gated) |
| `GET /api/v1/files/*` | New — streams a stored file (needs `Authorization`) |
| `/api/v1/projects/*`, `/api/v1/workspace/*` | Now require auth (401 anon) |

---

## 7. Your issues, mapped to backend state

| FE# | Now |
|---|---|
| FE#1 (PIN lockout) | **Unblocked.** Backend contract confirmed: PIN is super_admin/ghost-only. Gate `sessionUnlocked` on role. |
| FE#2 (ghost inverted) | **Flip now.** Direction is fixed and documented in `docs/Ghost-mode.md`. |
| FE#3 (fake uploads) | **Partially blocked.** Private file endpoint + read path exist; a *generic* upload endpoint does **not** — coordinate with us (§1c). |
| FE#5 (cold-start refresh) | **Unblocked.** Rotation/revocation semantics are final (§2a). |
| FE#6 (client timeouts) | **Align now** to the 60 s server write timeout (§5). |
| FE#7 (refresh-queue race) | Client-only; note refresh now returns a new refresh token to persist. |
| FE#12 (route guards) | Backend now enforces BFF auth (BE#1); client guards remain UX-only. Pin the role field to one source. |
| FE#13, FE#14 | Client-only; FE#14 improves now that logout truly revokes. |
| Money formatting | Touch every screen that shows an amount — see §1a. |

---

## 8. Known backend gaps (won't be fixed for you unless flagged)

- **No generic upload endpoint** — only `POST /projects/{id}/docs` (§1c, FE#3).
- **BE#33** (found during remediation): a NULL `installer_advance_amount` /
  `installer_final_amount` still crashes the scan in `ExecutionRepository`
  (contractor job/ledger reads) — columns default to 0, so it only bites on an
  explicitly-NULL row. The BFF project-details path is already guarded.
- Pagination response has no `next`/`prev` cursor — compute pages from
  `total`/`limit`/`offset`.

Questions or contract disagreements → raise them before building against an
assumption. Contract drift (ghost mode, PIN, the role field) is exactly what
caused this round of issues.
