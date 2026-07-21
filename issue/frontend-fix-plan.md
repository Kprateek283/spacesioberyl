# Frontend — Remediation Plan

Companion to `frontend-bugs.md`. No code, sequencing and approach only.
Numbering matches the bug report exactly.

**Ruling on Ghost Mode:** the **backend is correct** — `ghost_mode == true` means
cash is **visible**. The Flutter client is inverted and is what changes. See
item 2.

---

## Sequencing

| Wave | Contains | Gate to exit |
|---|---|---|
| 1. Unblock the app | 1, 2, 4 | Every role can reach the app; ghost mode behaves correctly |
| 2. Stop losing data | 3, 8, 9 | Nothing the user captures is silently discarded |
| 3. Network correctness | 5, 6, 7, 13, 14 | Sessions and requests behave predictably |
| 4. Hardening & hygiene | 10, 11, 12, 15, 16, 17, 18, 19, 20 | Backlog |

Item 1 blocks all manual testing by non-super-admin accounts, so it comes first
regardless of severity ranking. Item 4 is one line and unblocks the test suite —
do it in the same PR as item 1.

---

## Wave 1 — Unblock the app

### 1. Fix the PIN lockout for non-super-admin roles
This is a contract disagreement, not a bug on one side. Resolve the contract
before writing anything.

The client requires PIN verification for every role. The backend can only ever
satisfy that for `super_admin`, because PIN setup is restricted to that role and
PIN verification fails when no PIN hash exists. Every other user is stranded at
`/pin-entry` with no escape.

Two coherent resolutions — pick one with the product owner:

- **PIN is a super_admin ghost-mode control only.** The client stops gating on
  PIN for other roles: `sessionUnlocked` is satisfied immediately for anyone
  who cannot have a PIN. Frontend-only change, ships fast, matches the backend
  as built and matches how `docs/Ghost-mode.md` describes the feature.
- **PIN is an app-wide second factor.** Then the backend must allow all roles to
  set up and verify a normal PIN, and the ghost-mode high-security PIN remains
  super_admin-only. Larger change, spans both sides.

Recommend the first. The dual-PIN design exists specifically to toggle cash
visibility, which is meaningless for a role that can never see cash data.

Whichever is chosen, the two `sessionUnlocked: false` assignments and the router
redirect must agree with it, and the comment claiming "PIN verification is
required for every role" must be corrected — it currently documents a behaviour
the system cannot deliver.

**Verification:** log in as a sales user and reach the workspace. This has never
worked; confirm it manually, then add an integration test per role.

### 2. Flip Ghost Mode to match the backend
The backend is authoritative. Three widgets have the condition inverted and all
three change the same way: content that is currently hidden when `isGhostMode`
is true must be hidden when it is **false**.

Do these together, because a partial flip is worse than the current consistent
inversion:

- The three widgets' visibility conditions.
- The doc comments, which currently state the wrong semantics and are what led
  the implementation astray.
- The naming. "Ghost mode" reading as "things are hidden" is the trap. Consider
  renaming the client-side widgets to describe what they gate — cash visibility —
  rather than the mode name. The JWT claim keeps its name; only the widget names
  change. This is the durable fix; the condition flip alone leaves the next
  developer to make the same mistake.

Then find every usage. Confirm each call site still reads correctly after the
flip — some may have been written to compensate for the inversion, in which case
they will double-invert and break. Do not assume the widgets are the only place
`isGhostMode` is consulted.

**Verification:** with the high-security PIN, cash quotations appear. With the
normal PIN, cash input fields are absent and no request can be built that the
backend will reject with "cash payment terms require ghost mode to be enabled".
That rejection should become unreachable from the UI.

### 4. Fix the broken integration test
Add the missing Material import to `integration_test/qa_unified_ux_test.dart`.

Then actually run it. It has never executed, so expect it to fail on real
assertions once it compiles — those failures are information, not new bugs.
Budget time for them rather than treating the import as the whole task.

Note the process gap: a test was committed that does not compile, which means
`flutter analyze` is not running in CI. Fixing that is worth more than fixing
this file (see Cross-cutting).

---

## Wave 2 — Stop losing data

### 3. Replace the fake upload service
Every photo, signature and receipt the user captures is swapped for a fabricated
URL and never transmitted. This is the most damaging item in the report because
the loss is invisible — the request succeeds and the record persists.

Still blocked on the backend: a *generic* upload endpoint is needed. The backend
exposes its MinIO uploader only through the BFF project-docs route
(`POST /projects/{id}/docs`) — coordinate a generic `POST /files` as a joint
item. Backend #12/#31 shipped: the bucket is private and files are read back via
an **auth-gated `GET /api/v1/files/*`** endpoint (not presigned URLs) — the
upload response returns `file_url = /api/v1/files/<key>`, fetched with the bearer
token. See `frontend-handoff.md` §1c.

Client-side work, once the endpoint exists:
- Upload the file, then send the returned URL in the mutation. Two steps, and
  the failure of the first must block the second rather than falling through.
- Handle upload failure explicitly in the offline queue: a queued mutation with
  an un-uploaded file must stay queued, not send a placeholder.
- Delete `MockUploadService` entirely. Leaving it importable invites reuse.

Then deal with the existing damage. Any record already carrying a
`https://mock.local/...` URL has no file behind it. Identify them, and decide
whether affected users can be asked to re-capture. For contractor sign-offs this
is a financial audit-trail gap and someone needs to make an explicit call on it —
do not let it pass silently as a technical cleanup.

**Verification:** capture a signature offline, go online, and confirm the file
is retrievable from storage afterwards.

### 8. Stop head-of-line blocking in the sync queue
The outbox loop aborts on the first failure, so one permanently-failing mutation
blocks every valid one behind it. Continue past failures instead, letting each
item accrue its own retry count independently.

Add a periodic retry timer. Today, syncing only triggers on a connectivity
transition or a manual pull, so a device that stays online never retries — a
failed item can sit indefinitely without ever reaching its retry limit.

Consider ordering: if mutations have causal dependencies (create a job, then
update it), skipping a failed item and proceeding could apply them out of order.
Check whether the queued endpoints have such dependencies before changing the
loop. If they do, per-entity ordering with independent failure isolation is the
correct shape, not a flat continue.

### 9. Stop deleting failed mutations
After five attempts the mutation is deleted and the user's data is gone. The
UI surfaces the endpoint string, which is not enough to recover or even
understand what was lost.

Move exhausted mutations to a terminal failed state in the local database rather
than removing the row, and give the user a way to see what failed, with enough
context to identify it, plus retry and discard actions. Retention of the payload
is the point — the notification alone is not a fix.

Revisit the retry limit itself once #8 lands; five attempts against a
connectivity-only trigger is far more brittle than five against a timer.

---

## Wave 3 — Network correctness

### 5. Use the refresh token on cold start
Startup checks only the access token's expiry, so an hour after login the user
is bounced to the login screen despite holding a valid 30-day refresh token. The
refresh machinery exists and works — it is simply never reached, because it only
fires on a 401 from a live request and the app never issues one.

On startup, when the access token is expired but a refresh token is present,
attempt a refresh before falling back to signed out. Handle the refresh failing
(expired, revoked) by clearing storage and going to login, as today.

Backend #7/#8 has landed: `/refresh` now rotates the refresh token (store the new
one each time) and reuse of a rotated token revokes the whole family (→ 401,
re-login). Build against that. See `frontend-handoff.md` §2a.

Show a loading state during the startup refresh so the app does not flash the
login screen before landing on the workspace.

### 6. Add receive and send timeouts
Only `connectTimeout` is set, so a server that accepts a connection then stalls
leaves the request pending forever with the UI spinning and no recovery.

Set receive and send timeouts on all three Dio instances — the main client and
the two throwaway instances in the refresh path, which currently have no
timeouts at all. The refresh-path instances matter most: a stalled refresh hangs
every request queued behind it.

Better: build the throwaway instances from shared base options so a future
timeout change cannot miss one. The duplication is what caused the gap.

Coordinate the values with the backend's write timeout, now 60 s (backend #17
shipped), so the client does not give up before a legitimately slow endpoint
responds — set the client receive/send timeouts a little above 60 s.

### 7. Make the refresh queue race-free
A request that 401s in the narrow window after the queue is drained but before
the refreshing flag clears is appended to a queue nobody will drain, and its
handler is never resolved — the caller's future never completes.

Replace the mutable bool with a single completer representing the in-flight
refresh, which latecomers await. That removes the window structurally rather
than narrowing it. Trying to shrink the gap with reordering will not work; the
drain loop awaits, so a gap always exists.

While rewriting, confirm every path resolves or rejects each queued handler
exactly once — including the refresh-returns-non-200 branch and the exception
branch. An unresolved handler is an invisible hang; a double-resolve throws.

This code has been patched once already for the same class of bug (the comments
show it). It needs the structural fix, not a third patch.

### 13. Handle non-200 responses in the auth notifier
PIN setup and PIN verification leave the loading flag set forever on any
non-200 that Dio does not throw for, leaving the UI spinning with no error and
no recovery. Add explicit handling that clears loading and surfaces the failure.

Audit the other providers for the same shape — an `if (statusCode == 200)` with
no else is a pattern worth grepping for once and fixing everywhere.

### 14. Surface logout failures
Logout clears local state optimistically, then swallows any error from the
server call. The optimistic update is fine; the silent swallow is not — the user
is told they are signed out while the session may remain live server-side.

This is materially better now that backend #7 makes logout actually revoke the
refresh token server-side. Still surface the failure (at minimum log it). Decide whether the
user should be told; for a shared-device scenario, a failed server-side logout
is something they would want to know about.

---

## Wave 4 — Hardening and hygiene

### 10. Configuration and transport security
Three related changes:

- Move the API URL out of the bundled `.env` asset to a build-time define. The
  file is extractable from any APK; it holds only a URL today, but the pattern
  invites putting a secret there later.
- Remove the hardcoded `http://localhost` fallbacks, duplicated in two places.
  A release build that ships without configuration should fail loudly, not
  silently send credentials in the clear.
- Enforce HTTPS in release builds, and evaluate certificate pinning. Given
  financial data and long-lived refresh tokens, pinning is defensible — weigh it
  against the operational cost of certificate rotation before committing.

### 11. Remove the blanket lint suppressions
Seventeen files disable `use_build_context_synchronously` at file level, which
switches the check off for every async gap in the file rather than the one that
was reviewed. The lint catches a real crash class.

Remove each directive and fix the resulting warnings with mounted checks after
awaits. Mechanical but not automatic — each site needs a decision about what
should happen when the widget is gone.

Do it file by file rather than in one sweep; a 17-file diff touching every screen
is unreviewable, and some sites will turn out to be genuine bugs deserving
individual attention.

Then consider promoting the lint to an error so it cannot be suppressed again
without a deliberate conversation.

### 12. Role-based route guards
Route redirects check authentication but not role; the role is passed to widgets
as a display-level flag only. Add role checks to the redirect logic for
role-restricted sections.

Client-side guards are UX, not security — the backend must enforce
authorization regardless. Backend #1 is resolved: the BFF now requires auth, so
the server-side exposure is closed; this item only stops users from navigating
into screens that will fail or show data they should not see.

Derive the role from a single source. It is currently read from the stored user
payload with fallbacks across two possible field names, which suggests the
backend response shape was uncertain. Pin the contract down and remove the
fallback.

### 15. Project structure
One login screen sits outside the feature-first layout that everything else
follows, in a directory that exists for that single file. Move it and delete the
directory. Pure hygiene; bundle it with any PR touching auth screens.

### 16. Dead dependencies
The Riverpod code-generation trio is declared but entirely unused — no
annotations, no generated files. Either drop the three packages or adopt the
pattern. Carrying both styles gives the costs of each and the benefits of
neither.

Recommend dropping them. The manual providers work and are readable; adopting
codegen now is a large diff for no functional gain.

### 17. Dependency upgrades
Eighty-three packages are behind, including Riverpod two majors back. Plan a
deliberate upgrade window rather than doing it under time pressure later. Take
the Riverpod major separately from the routine bumps, since it will carry
breaking API changes across every provider in the codebase.

Do this after waves 1–3. Upgrading on top of known-broken behaviour makes it
impossible to tell which failures are new.

### 18. Remove prints from test code
Eight `avoid_print` warnings across the manual DB script and the integration
test. Trivial; do it while fixing item 4.

### 19. Deduplicate the base URL read
The API URL is read from configuration twice with duplicated fallbacks. Collapse
to one source. Ties into item 10 — do them together.

### 20. Add tests for the logic that keeps breaking
The test directory holds only a manual database inspection script. The three
most defect-dense areas in this report — ghost-mode visibility, the 401 refresh
queue, and the sync outbox — have no coverage at all, and items 2, 7 and 8 would
each have been caught by one small test.

Priority order:
1. Ghost-mode widget tests pinning visibility in both states. These lock in the
   direction after item 2 and prevent a re-inversion.
2. Sync outbox tests: failure isolation, retry accounting, terminal state.
3. Refresh-queue tests: concurrent 401s, refresh failure, the late-arrival race.

Write these as part of the corresponding fixes, not as a follow-up task. A
follow-up test task after the fix has shipped will not survive contact with the
next priority.

---

## Cross-cutting

**CI is the actual gap.** A test that does not compile reached `dev`. Add
`flutter analyze` and the test suite to CI as a merge gate. That single change
prevents the entire class of problem item 4 represents, and it costs less than
most individual items in this plan.

**Contract drift is the theme.** Items 1, 2 and 12 are all the same failure: the
client assumed a backend behaviour that does not exist, and nothing caught the
divergence. Ghost mode is inverted, PIN gating is impossible to satisfy, and the
role field is read with a defensive fallback across two names. Consider
generating or at least documenting the API contract in one shared place, and
adding integration tests that run the Flutter client against a real backend for
the auth and ghost-mode flows specifically.

**Coordinate these with the backend plan:** item 3 (still needs a generic upload
endpoint), item 5 (refresh-token semantics — now final), item 6 (timeout values
— now 60 s), item 12 (authorization is enforced server-side — now including the
BFF). Backend #15 has shipped: money is int64 **paise** on the wire, so every
amount field needs ÷100 on display and ×100 on input — see `frontend-handoff.md`
§1a. The full backend-to-frontend contract is in `frontend-handoff.md`.
