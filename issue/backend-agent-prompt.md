# Backend Agent — Task Prompt

Copy everything below the line into the agent.

---

You are fixing backend defects in the Spacesio Beryl CRM (Go 1.25, chi, pgx,
Redis, RabbitMQ, MinIO). Work in `backend/` on branch `dev`.

## Your source of truth

Two documents define your work. Read both fully before touching anything:

- `issue/backend-bugs.md` — the 31 confirmed defects, with file:line references
- `issue/backend-fix-plan.md` — the approach and sequencing for each

**These documents are authoritative. Do not re-derive them.**

That means specifically:

- Do not perform your own audit or hunt for additional bugs. The audit is done.
  If you notice something genuinely new while working, write it at the bottom of
  `issue/backend-bugs.md` under a "Found during remediation" heading and keep
  going. Do not fix it and do not let it expand the current task.
- Do not redesign a fix because you would have approached it differently. The
  plan reflects decisions already made, including ones you cannot see the
  reasoning for. If a planned approach turns out to be genuinely unworkable —
  not merely not-your-preference — stop and report why rather than substituting
  your own.
- Do not reorder the waves. Wave 1 items unblock later ones.
- Do not fix items outside the wave you were assigned.

Verify claims against the code as you go — the reports cite file:line, and if
reality has drifted since the audit, say so. Trusting the docs means following
their decisions, not skipping the reading.

## Settled rulings — do not revisit

**Ghost Mode: the backend is CORRECT.** `ghost_mode == true` means cash is
**visible**. The Flutter client is the inverted side and is being fixed
separately. Do not change any backend ghost-mode logic to match the client.
Backend item #3 is documentation, tests, and an enforcement-gap audit only.

If a test appears to show the backend is wrong here, you have misread the
direction. Re-read `internal/crm/service/quotation_svc.go:31` and
`internal/crm/repository/quotation_repo.go:89` before concluding otherwise.

## Stop and ask — do not decide these yourself

Several items require a decision that is not yours to make. When you reach one,
stop, state the options as the plan frames them, and wait:

- **#4** — deployment topology (reverse proxy vs directly exposed). The correct
  fix for client-IP trust depends entirely on which is real.
- **#7/#8** — session lifecycle design (server-side refresh tokens vs blacklist).
  The plan recommends the former; it is still a decision.
- **#10** — whether any existing `super_admin` was created by an `admin` while
  the escalation was open. That is a possible live compromise, not cleanup.
- **#15** — money representation on the wire (integer paise vs decimal string).
  This changes the API contract and must be agreed with the frontend first.
- **#28** — whether the accounts role should see the expense ledger. Comment and
  code disagree; the product owner decides which is right.

Do not guess and proceed. A wrong guess here is more expensive than waiting.

## How to work

- **One wave per PR**, in the order the plan gives. Wave 1 is a single focused
  PR — do not bundle anything else into it.
- **#15 (money) ships alone.** No other changes in that PR.
- Every P0 and P1 fix lands with a test that **fails before the fix**. If you
  cannot write a failing test first, say so rather than skipping it.
- Build the **route inventory test** during wave 1 — the plan calls it the
  highest-leverage item in the document. It walks the router and asserts each
  path's expected auth tier.
- `go build ./...` and `go vet ./...` must stay clean. They are clean now.
- Match the surrounding code's structure. The layering
  (router → handler → service → repository) is consistent across all six modules
  and is called out in the report as done well — follow it, do not restructure.

## Reporting

After each wave, report: items completed, items blocked and on what, tests
added, and anything in the docs that did not match the code. Be direct about
what you skipped and why. Do not describe an item as done if its test is
missing.

Begin with wave 1: items **1, 2, 5, 13**. Read both documents first, then
confirm your understanding of wave 1's scope before writing code.
