# Codebase Audit — Executive Summary

> **Status update (2026-07-10, later same day):** items 1–4 below (navigation, fake uploads, UI/wireframe mismatch, PIN bypass) have since been fixed in the frontend — see the "Resolution" sections in [02-frontend-issues.md](02-frontend-issues.md) and [03-ui-ux-wireframe-audit.md](03-ui-ux-wireframe-audit.md). Item 5 (`JWT_SECRET`) and item 6's backend half (test credentials) remain open by explicit instruction — no backend code changes were made; see [01-backend-issues.md](01-backend-issues.md). The rest of this file is kept as the original as-found audit record.

**Date:** 2026-07-10
**Method:** Independent re-verification of the codebase on disk (source reading, `go build`/`go vet`/`go test`, `flutter analyze`/`flutter test`, `git log`/`git ls-files`) — not a re-statement of `QA_REPORT.md` or `qa_bug_report.md`. Those two prior documents in the repo root **contradict each other** (one lists bugs, the other claims all are fixed and the app is "READY FOR PRODUCTION"). Neither claim was taken at face value; every item was re-checked against current code.

**Verdict: the app is not production-ready.** The backend is in reasonably good shape. The frontend has a critical navigation defect that makes most of the built product inaccessible to users, plus a mock file-upload service silently discarding real user data. The UI does not match the wireframe design spec, and also doesn't consistently follow its own theme file. The test suites (backend and frontend) are broken/stale and do not currently pass.

---

## Top 6 issues, ranked by impact

1. **Most of the app is unreachable from the UI.** The bottom navigation and router only wire up 3 screens (Workspace, Pipeline, Profile). All of HR, IAM (beyond login/PIN), Logistics, Execution, and most of CRM (Leads board, Followups, Complaints) exist as compiled, working code but have **no path a user can tap to reach them**. See [02-frontend-issues.md](02-frontend-issues.md#critical-most-of-the-app-is-orphaned-dead-code).

2. **File uploads are faked.** `MockUploadService` generates a fake `https://mock.local/...` URL instead of actually uploading files, and is wired into expense receipts, site-update photos, and **client sign-off signatures**. The backend permanently stores these broken URLs; the real image/signature bytes are discarded. See [02-frontend-issues.md](02-frontend-issues.md#critical-uploads-are-fake).

3. **UI does not match the design spec, and is internally inconsistent.** The wireframes specify a green Material 3 design system; the app's own theme file (`app_theme.dart`) is black/white/gray; but most actual screens hardcode a *third*, different palette (Material blue `0xFF0061a4`, plus a rainbow of ad hoc colors for status chips). Several flagship screens the wireframes designed in detail (Kanban leads board, full quotation builder, numpad PIN lock screen, progress-tracked job cards) were replaced with generic lists and dialogs. See [03-ui-ux-wireframe-audit.md](03-ui-ux-wireframe-audit.md).

4. **PIN/Ghost Mode security is bypassed for every role except `super_admin`.** On login, `sessionUnlocked` is set `true` immediately for `admin`/`staff`/other roles, so the PIN screen — the app's core security feature — never appears for them. See [02-frontend-issues.md](02-frontend-issues.md#high-pinghost-mode-bypass-for-non-super_admin-roles).

5. **`JWT_SECRET=secret` is still the live value** in the working `.env` used to sign every token. (The good news: `.env` itself is correctly gitignored and was never committed — no secret leaked via git history. But the weak secret is live in the running system today.) See [01-backend-issues.md](01-backend-issues.md#critical-jwt_secretsecret-still-live).

6. **Both test suites are currently broken and do not reflect the real app.** `flutter test` fails on the untouched Flutter-starter counter test. `flutter integration_test/*` reference screens/tabs (`"CRM"` tab, `"Team Dashboard"`) that no longer exist in the wired-up navigation. `go test ./...` fails because the test fixtures use `admin@company.com`/`newpass123`, which doesn't match the actual seeded credentials `admin@gmail.com`/`admin123`. See [04-testing-strategy.md](04-testing-strategy.md).

---

## What's genuinely good

- The backend's core business logic is solid: Ghost Mode cash-payment enforcement, quotation DB transactions, RabbitMQ channel-per-publish (no more shared-channel races), follow-up cancellation on lead loss, and 12 of the 18 previously-reported backend/flow bugs are confirmed fixed with evidence.
- No SQL injection found anywhere — all dynamic queries use parameterized placeholders.
- `.env` secrets are correctly gitignored and have never been committed to git history (verified directly, not assumed).
- The frontend's login-flow fixes (form validation, forgot-password wiring, sqflite/image_picker web compatibility) are genuinely fixed and verified.
- The app's theme file (`app_theme.dart`) itself, where actually used, is a clean, well-built monochrome Material 3 system — the problem is that most screens bypass it, not that it's poorly designed.

## Files in this folder

- [01-backend-issues.md](01-backend-issues.md) — Go backend: security, correctness, architecture, error handling
- [02-frontend-issues.md](02-frontend-issues.md) — Flutter frontend: navigation, state management, error handling, platform, test infra
- [03-ui-ux-wireframe-audit.md](03-ui-ux-wireframe-audit.md) — comparison of implemented UI against `/frontend-integration/wireframe-design/`
- [04-testing-strategy.md](04-testing-strategy.md) — recommended automated testing setup to catch backend/frontend integration drift going forward
