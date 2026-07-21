# Frontend Agent — Task Prompt

Copy everything below the line into the agent.

---

You are fixing frontend defects in the Spacesio Beryl CRM (Flutter 3.5,
Riverpod, go_router, Dio, sqflite). Work in `frontend/` on branch `dev`.

## Your source of truth

Two documents define your work. Read both fully before touching anything:

- `issue/frontend-bugs.md` — the 20 confirmed defects, with file:line references
- `issue/frontend-fix-plan.md` — the approach and sequencing for each

**These documents are authoritative. Do not re-derive them.**

That means specifically:

- Do not perform your own audit or hunt for additional bugs. The audit is done.
  If you notice something genuinely new while working, write it at the bottom of
  `issue/frontend-bugs.md` under a "Found during remediation" heading and keep
  going. Do not fix it and do not let it expand the current task.
- Do not redesign a fix because you would have approached it differently. The
  plan reflects decisions already made, including ones you cannot see the
  reasoning for. If a planned approach turns out to be genuinely unworkable —
  not merely not-your-preference — stop and report why rather than substituting
  your own.
- Do not reorder the waves.
- Do not fix items outside the wave you were assigned.

Verify claims against the code as you go — the reports cite file:line, and if
reality has drifted since the audit, say so. Trusting the docs means following
their decisions, not skipping the reading.

## Settled rulings — do not revisit

**Ghost Mode: the BACKEND is correct and the FRONTEND is inverted.**
`ghost_mode == true` means cash is **visible**. You are flipping the client to
match. Do not "fix" this by changing what you send to the backend, and do not
file it as a backend bug — that determination has been made.

Backend enforcement points, for reference only (do not edit these files):
`backend/internal/crm/service/quotation_svc.go:31` and
`backend/internal/crm/repository/quotation_repo.go:89`.

When flipping, the plan requires all three of: the widget conditions, the doc
comments, and a review of every `isGhostMode` call site. A partial flip is worse
than the current consistent inversion — some call sites may have been written to
compensate and will double-invert. Check them all.

## Stop and ask — do not decide these yourself

- **#1 (PIN lockout)** — whether PIN is a super_admin ghost-mode control only
  (frontend-only fix, recommended) or an app-wide second factor (needs backend
  work too). This is a product decision. Do not pick one and build it.
- **#3 (fake uploads)** — the disposition of records already carrying
  `https://mock.local/...` URLs. For contractor sign-offs this is a financial
  audit-trail gap. Someone must make an explicit call; it is not technical
  cleanup for you to decide.
- **#12** — which roles may reach which sections, if the plan's list is not
  already unambiguous.

Do not guess and proceed.

## Blocked on the backend — do not start unilaterally

Three items are joint. Coordinate before writing code:

- **#3** needs a generic upload endpoint that does not exist yet, and its
  contract interacts with backend plan #12 (private bucket, presigned URLs).
  Agree the upload *and* read-back shape once, covering both.
- **#5** depends on refresh-token rotation semantics that backend plan #7/#8 is
  changing. Building against today's behaviour means reworking it.
- **#6** timeout values should be chosen against the backend's write timeout
  (backend plan #17), not picked independently.
- Any money-formatting change follows backend plan #15's wire-format decision.

## How to work

- **One wave per PR**, in the order the plan gives.
- Item **4** (the missing Material import) goes in the same PR as item 1 — it is
  one line and it unblocks the test suite. Expect the test to then fail on real
  assertions once it compiles; those failures are information, not new bugs.
  Budget time for them.
- Item **11** (17 blanket lint suppressions) goes **file by file**, not as one
  sweep. A 17-file diff across every screen is unreviewable, and some sites will
  be genuine bugs needing individual attention.
- Write the tests listed in item 20 **as part of the corresponding fixes**, not
  as a follow-up. Specifically: ghost-mode visibility tests land with item 2,
  sync-outbox tests with item 8, refresh-queue tests with item 7. A test task
  deferred until after the fix ships will not survive the next priority.
- `flutter analyze` must be clean when you finish. It currently reports 15
  issues; 7 are item 4.
- Match the surrounding code. The offline outbox architecture and the
  centralised auth `StateNotifier` are called out in the report as sound —
  refine them, do not rewrite them.

## Reporting

After each wave, report: items completed, items blocked and on what, tests
added, and anything in the docs that did not match the code. Be direct about
what you skipped and why. Do not describe an item as done if its test is
missing.

Begin with wave 1: items **1, 2, 4** — noting that item 1 needs the product
decision above before you can implement it. Read both documents first, then
confirm your understanding of wave 1's scope and raise the item 1 question
before writing code.
