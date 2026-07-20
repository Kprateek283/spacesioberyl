# Frontend Issues (Flutter — `frontend/lib/`)

Independently re-verified against current source. `flutter analyze` and `flutter test` were run directly; findings are traced to exact file:line. Severity: Critical / High / Medium / Low.

## Resolution (2026-07-10, updated)

All code-level issues below were fixed in the frontend, across two passes: an initial bug-fix pass, and a follow-up pass that rebuilt the navigation/UI to match the wireframes (see [03-ui-ux-wireframe-audit.md](03-ui-ux-wireframe-audit.md) for that side of it). Summary:

- **Navigation:** replaced the broken 3-tab shell with a 5-tab bottom nav (Home / CRM / Logistics / Execution / HR) matching the wireframe's intended IA — every module is now a direct, reachable tab instead of hidden behind a "More" menu. `MoreMenuScreen` was removed once its contents were absorbed into the new CRM Kanban board (Follow-ups/Complaints reachable via AppBar icons), the new HR hub screen, and per-screen Profile icons.
- **Uploads:** **partially resolved, then intentionally reverted.** A generic authenticated `POST /api/v1/uploads` backend endpoint was built and the frontend wired to it end-to-end (real uploads for receipts, site photos, contractor check-ins, client signatures, and quotation PDFs). Per an explicit instruction to make no backend changes, **the backend endpoint was removed and the frontend wiring was reverted back to `MockUploadService`** so the app doesn't call a non-existent endpoint. The app is functionally consistent again (fake upload URLs, as before), but this is a known gap — see [01-backend-issues.md](01-backend-issues.md) for what the backend needs to close it for real.
- **PIN bypass:** removed the `role != 'super_admin'` exemption in `auth_provider.dart` — PIN verification is now required for every role, via a rebuilt numpad lock screen (PIN dots, auto-submit) matching the wireframe.
- **Silent data loss:** dropped offline mutations (5 failed retries) now surface in `SyncBanner` instead of vanishing silently.
- **Swallowed errors:** fixed the contractor-payment dialog (API call was running fully detached from any error handler due to premature dialog-pop), the empty `catch (_) {}` in the assign-manager flow, and added missing `mounted`/`context.mounted` guards across CRM/logistics screens (removing the blanket `ignore_for_file: use_build_context_synchronously` directives that were masking them).
- **Medium fixes:** `api_client.dart`'s 401-retry queue now actually resolves/rejects the original caller's request instead of dropping it and firing an untracked duplicate; `SyncService`'s connectivity listener is now cancelled via `ref.onDispose`; PIN/login screen `TextEditingController`s now have `dispose()`.
- **Dead code removed:** `auth_service.dart`, the duplicate `lib/services/hr_service.dart`, the orphaned legacy `admin_dashboard_screen.dart`/`staff_home_screen.dart`, and the now-redundant simpler `workspace/screens/profile_screen.dart` (standardized on the more complete `iam/screens/profile_screen.dart`).
- **Test infra:** `test/widget_test.dart` replaced with a real smoke test for this app; all `integration_test/*.dart` files updated twice — once for the 4-tab shell, then again for the final 5-tab shell and numpad PIN entry — and their lint warnings fixed.
- **Design system:** rebuilt `AppColors`/`AppTheme` from the wireframes' actual Material 3 tokens (emerald `#0F5238` seed, IBM Plex Sans + Inter via `google_fonts`), and swept ~170 hardcoded color literals across ~25 screens to use it instead.
- **Low severity:** all `withOpacity` deprecations replaced with `withValues(alpha:)`, deprecated `ButtonBar` replaced with `OverflowBar`, unused imports removed.

Verified with `flutter analyze` (0 issues in `lib/`, `integration_test/`, `test/`) and `flutter test` (passing) after every pass, most recently after the upload revert. The `integration_test/*.dart` changes are structurally correct against current widget text/routes but were **not executed** in this session — running them requires a live backend + emulator/Chrome, which wasn't available in this environment.

Not in scope for this pass (tracked elsewhere): backend fixes and the missing generic upload endpoint, now documented in [01-backend-issues.md](01-backend-issues.md) rather than implemented, per explicit instruction to make no backend changes.

---

## Status of previously-reported issues (`qa_bug_report.md` BUG-F01–F12)

| ID | Verdict | Notes |
|---|---|---|
| F01 Login bypasses PIN flow | **Partially fixed** | Fixed *only* for `super_admin`. See Critical finding below — every other role still bypasses PIN entirely. |
| F02 No form validation | **Fixed** | `GlobalKey<FormState>` + validators in `login_screen.dart:15,212-222,262-265`. |
| F03 "Keep me signed in" non-functional | **Fixed** | Checkbox removed entirely. |
| F04 Static forgot-password message | **Fixed** | Real dialogs now call `POST /password/forgot` and `POST /password/reset` with error handling. |
| F05 sqflite crashes on web | **Fixed** | `database_helper.dart` branches on `kIsWeb` and uses in-memory caches (lost on refresh — a limitation, not a crash). |
| F06 image_picker no camera on web | **Fixed** | `kIsWeb ? ImageSource.gallery : ImageSource.camera` in `site_updates_screen.dart:92`. |
| F07 Missing error display in auth flows | **Fixed** | `pin_entry_screen.dart`/`pin_setup_screen.dart` both wrap calls in try/catch with `UiFeedback.parsedError`. |
| F08 Router only 2 routes, no deep linking | **Partially fixed — QA_REPORT's specific claim is false** | Router now has proper `GoRouter`/`redirect`/`ShellRoute` (7-8 routes), a real improvement. But the claim "deep linking (`/crm`, `/logistics`) functions flawlessly" is verifiably false — no such routes exist. See Critical finding below. |
| F09 AuthWrapper dual-purpose | **Fixed** | `main.dart` no longer contains `AuthWrapper`; routing/auth cleanly handled via `router.dart`'s `redirect`. |
| F10 verifyPin redundant checkAuthStatus call | **Fixed** | `auth_provider.dart:166-193` sets state directly from the verify-pin response. |
| F11 cacheBootSyncProvider watched in build() | **Mostly fixed, residual smell** | Changed to `ref.read()`; the underlying provider caches its result so it doesn't actually re-fire HTTP calls, but a side-effecting read inside `build()` remains a code smell. |
| F12 No loading states / dummy data | **Partially fixed, new issues found** | Real loading states exist on the two reachable data screens, but several "Quick Action" buttons are dead no-ops (see below). |

---

## Critical: most of the app is orphaned dead code

- **Files:** `frontend/lib/core/routes/router.dart`, `frontend/lib/core/widgets/main_shell_screen.dart:16,21-33`
- The bottom navigation has exactly **3 tabs**: Workspace, Pipeline, Profile. The router only defines routes to `WorkspaceScreen`, `PipelineScreen`, `ProfileScreen`, plus `/pipeline/project/:id` (CRM lead detail).
- Every HR, IAM (beyond login/PIN), Logistics, and Execution screen, plus CRM Followups and Complaints, **compiles and works** but is only ever instantiated inside `more_menu_screen.dart` — and `MoreMenuScreen` is imported in `router.dart:15` but **never used** (`flutter analyze` confirms: `warning - Unused import`). There is no button anywhere in the live UI that opens it. `WorkspaceScreen`'s quick-action buttons are also no-ops (see below), so nothing links out to it either.
- `main_shell_screen.dart:16` computes `isAdmin` and never uses it — a remnant of a dropped admin/"More" tab, confirming this was a regression from a prior navigation architecture rather than an intentional cut.
- Also orphaned: `frontend/lib/screens/admin/admin_dashboard_screen.dart` and `frontend/lib/screens/staff/staff_home_screen.dart` (old "Team Dashboard"/"Studio CRM" screens) — never referenced by the current router or shell.
- **Impact:** the vast majority of the built product — HR attendance/leave/expenses, all of Logistics, all of Execution, the CRM leads board, followups, complaints — is inaccessible to a real user today. This directly contradicts `QA_REPORT.md`'s "READY FOR PRODUCTION" verdict.
- **Fix:** either restore a 5th nav destination (e.g. "More"/module menu) routing to `MoreMenuScreen`, or expand the bottom nav/shell to cover all modules per the design spec's intended IA (see [03-ui-ux-wireframe-audit.md](03-ui-ux-wireframe-audit.md)).

## Critical: uploads are fake

- **File:** `frontend/lib/core/network/mock_upload_service.dart` (entire file)
- Generates a fake `https://mock.local/<bucket>/<filename>` URL instead of uploading anything. Wired into:
  - `frontend/lib/features/hr/services/hr_service.dart:153` (expense receipts)
  - `frontend/lib/features/execution/services/execution_service.dart:170-171` (site-update photos)
  - `frontend/lib/core/widgets/signature_canvas_widget.dart:62-65` (**client sign-off signatures**)
  - `frontend/lib/core/network/sync_service.dart:71-83` (any `*_url` field replayed from the offline outbox)
- **Failure scenario:** an employee submits an expense receipt, or a client signs off on installation completion — the backend permanently stores a `receipt_url`/`client_signoff_url` pointing to `https://mock.local/...`, which resolves nowhere. The real image/signature bytes are discarded client-side. For a compliance-relevant flow like client sign-off, this is a serious business-correctness defect.
- **Fix:** wire `MockUploadService` up to the real MinIO upload endpoint the backend already exposes (see `backend/internal/storage/minio.go`).

## High: PIN/Ghost Mode bypass for non-`super_admin` roles

- **File:** `frontend/lib/features/auth/providers/auth_provider.dart:77,130-136`
- `sessionUnlocked: roleName != 'super_admin'` (and the same pattern in `checkAuthStatus()`) means **every role except `super_admin`** — i.e. `admin`, `staff`, and any other role — gets full app access immediately on login/cold boot, with the PIN screen never appearing.
- **Failure scenario:** a `staff` account logs in and goes straight to the dashboard with no PIN gate at all, even though the PIN-setup and Ghost Mode PIN UI clearly exist and imply universal PIN gating.
- **Fix:** remove the role-based exemption; require PIN unlock for all authenticated roles.

## High: silent data loss in offline sync

- **File:** `frontend/lib/core/network/sync_service.dart:63-66,92-95`
- After 5 failed sync attempts, a queued offline mutation (expense receipt, leave request, site update, dispatch log) is silently removed from the queue with no user-facing notification — only a pending-count badge updates.
- **Failure scenario:** a technician submits a site update while offline; it keeps failing (e.g. a stale foreign key); after 5 background retries it vanishes permanently with no error ever shown to the user.
- **Fix:** surface a persistent failure notification (not just a count) and/or keep failed mutations visible for manual retry/dismissal.

## High: contractor payment failure not caught

- **File:** `frontend/lib/features/execution/screens/job_detail_screen.dart` ("Record Payment" flow)
- The async submit closure isn't wrapped by the outer try/catch (which only wraps `showDialog`), so a failed `recordContractorPayment` call throws unhandled while the UI proceeds to reload as if payment succeeded.
- **Failure scenario:** the payment API call fails; the user sees no error and believes the payment was recorded.
- **Fix:** wrap the actual API call in try/catch with user-facing error feedback, not just the dialog presentation.

## High: assign-manager failures silently swallowed

- **File:** `frontend/lib/features/logistics/screens/logistics_orders_screen.dart:143`
- `try { ... } catch (_) {}` — fully empty catch block on the assign-manager dialog submit.
- **Failure scenario:** assigning an operations manager to an order fails; the dialog closes and the list refreshes as if it succeeded.
- **Fix:** surface the error via `UiFeedback.parsedError` like other flows in the codebase already do correctly.

## Medium

- **`api_client.dart:82-84`** — in `_handle401Error`, queued retry requests are fired without `await` or error handling after a token refresh. A failed retry is invisible; UI state can become inconsistent.
- **`sync_service.dart:30-37`** — `Connectivity().onConnectivityChanged` subscription is never stored/cancelled; no `ref.onDispose`. Provider re-creation stacks duplicate listeners, risking concurrent double-syncs of the offline queue.
- **`pin_setup_screen.dart:14-15`, `pin_entry_screen.dart:14`** — `TextEditingController`s with no `dispose()` override — confirmed leak on screens hit every cold boot / session lock.
- **Missing `mounted`/`context.mounted` guards after `await`:** `job_detail_screen.dart:91-109` (`_assignInstaller`), `crm_complaints_screen.dart:138-148`, `my_dispatches_screen.dart:23-33` (which additionally suppresses the lint via a file-level `ignore_for_file` rather than fixing it), `crm_followups_screen.dart:75-89`.
- **`auth_service.dart`** (entire file) — dead legacy class, unreferenced elsewhere, using a stale API contract (`username`/`password`, flat `token`) that doesn't match the real backend (`email`/`password`, `access_token`/`refresh_token`). Harmless while unreferenced, but a landmine if a future developer wires it back in because it looks complete.
- **Dead "Quick Action" buttons:** `workspace_screen.dart:52,54,56,76-79` (Clock In/Out, Request Leave, Claim Expense, Manager Inbox "Review" are all `onPressed: () {}`), `pipeline_screen.dart:36-39` ("Add Lead" FAB is a documented placeholder — meaning the only lead-creation entry point in the *reachable* UI is nonfunctional, since the real working create-lead flow in `crm_leads_screen.dart` is itself orphaned per the Critical navigation finding above).

## Low / Code quality

- Widespread `withOpacity` deprecation warnings (12+ occurrences across `pin_entry_screen.dart`, `pin_setup_screen.dart`, `my_attendance_screen.dart`, `my_expenses_screen.dart`, `my_leaves_screen.dart`, `admin_dashboard_screen.dart`, `login_screen.dart`, `module_tile.dart`).
- `logistics_orders_screen.dart:289` uses the deprecated `ButtonBar` (should be `OverflowBar`).
- No `TODO`/`FIXME` comments exist anywhere in `lib/` — this isn't a positive; it means the orphaned-screens and mock-upload issues above were never even flagged inline, they were simply left unwired.

---

## Testing infrastructure findings

- **`flutter test` fails.** `frontend/test/widget_test.dart` is still the untouched Flutter-starter "Counter increments smoke test" — it has never been adapted to this app and fails immediately looking for text "0"/"1" that doesn't exist. There is effectively **zero working unit/widget test coverage**.
- **`frontend/integration_test/*.dart` are substantive but stale.** They simulate real multi-step flows (login → PIN → CRM lead → quotation → logistics order, etc.) but reference tab labels/screens (`"CRM"` tab, `"Logistics"` tab, `"Team Dashboard"`, `"Studio CRM"`) that belong to the old navigation structure and no longer exist in the wired-up app (per the Critical navigation finding above) — none of these could currently pass. `qa_unified_ux_test.dart` is a 1-assertion stub and is even wrong about the login button's exact text ("Log In" vs "Login").
- `flutter analyze` reports 53 issues (no fatal errors — the app compiles), including unused imports and always-true type checks specifically inside the integration test files, consistent with tests written once and never re-run after the navigation refactor that orphaned most screens.

See [04-testing-strategy.md](04-testing-strategy.md) for recommendations.

## API integration spot-check

Payload shapes in `api_client.dart` (e.g. login using `email`/`password` → `access_token`/`refresh_token`; CRM lead status enum) look internally consistent with what `auth_provider.dart` and `crm_leads_screen.dart` consume, and the BUG-B01 enum mismatch does appear resolved frontend-side. A full DTO-by-DTO cross-check against backend Go structs was not performed in this pass — flagged as a gap for the automated contract testing recommended in [04-testing-strategy.md](04-testing-strategy.md), rather than a confirmed finding.
