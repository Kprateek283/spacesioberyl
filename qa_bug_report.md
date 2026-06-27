# Spacesio Beryl - QA Bug Report

**Date:** 2026-06-28
**Tester:** AI QA (Antigravity)
**Scope:** Full backend API testing (91 endpoints) + Frontend code review + Architecture review

---

## Test Summary

| Metric | Value |
|---|---|
| Total API Tests Run | 91 |
| Passed | 89 |
| Failed (Expected Edge Cases) | 2 |
| Backend Bugs Found | 8 |
| Frontend Bugs Found | 12 |
| Flow/Integration Bugs | 6 |
| Logical Errors | 5 |
| Security Issues | 4 |
| Documentation Mismatches | 3 |

---

## Bug Classification

### BACKEND BUGS

#### BUG-B01: Lead Status Enum Mismatch [Severity: HIGH]
- **Type:** Backend / Logical Error
- **File:** [lead_svc.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/crm/service/lead_svc.go#L21-L24)
- **Description:** The `validLeadStatuses` map uses `first_call` but the API contracts documentation lists `contacted` as a valid status. The frontend testing guide also references statuses inconsistent with what the backend accepts.
- **Valid statuses in code:** `new, first_call, pdf_sent, sample_sent, site_visit, negotiation, finalized, lost`
- **Documented statuses:** `contacted, negotiation` (in api_contracts.md)
- **Impact:** Frontend forms sending `contacted` will receive 400 errors.
- **Fix:** Either update the backend enum to include `contacted` or update all docs/frontend to use `first_call`.

---

#### BUG-B02: Logistics Module Missing Service Layer [Severity: MEDIUM]
- **Type:** Backend / Architecture
- **File:** [app.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/app/app.go#L164-L168)
- **Description:** The Logistics module skips the service layer entirely. The handler directly calls the repository (`logHandler.NewLogisticsHandler(repo)`). All other modules follow handler -> service -> repository pattern. This breaks the architecture's consistency and means business logic validation happens in the handler or not at all.
- **Impact:** No centralized business logic for vendor, order, dispatch operations. Validation rules are scattered or missing.

---

#### BUG-B03: Ghost Mode Not Enforced on Quotation Creation [Severity: HIGH]
- **Type:** Backend / Security / Logical Error
- **File:** [quotation_svc.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/crm/service/quotation_svc.go#L29-L97)
- **Description:** The `module_flows.md` documentation states: "Cash terms are blocked if `ghost_mode` is false." However, the `Create` method in `QuotationService` **never checks** the `ghost_mode` claim from the JWT context. Any authenticated user can create a quotation with `payment_term_type: "cash"` regardless of their ghost mode state.
- **Impact:** The core Ghost Mode security feature is not enforced server-side for quotations.
- **Fix:** The `Create` handler needs to extract `ghost_mode` from context and reject `cash` payment terms when `ghost_mode == false`.

---

#### BUG-B04: OTP Generation Truncation Risk [Severity: LOW]
- **Type:** Backend / Logical Error
- **File:** [iam_service.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/iam/service/iam_service.go#L322-L324)
- **Description:** The OTP generation uses `fmt.Sprintf("%06d", int(b[0])<<16|int(b[1])<<8|int(b[2]))[:6]`. The max value of a 3-byte integer is 16,777,215 (8 digits). `Sprintf("%06d", ...)` with 8-digit numbers produces an 8-character string, then `[:6]` truncates it. This means the OTP is NOT uniformly distributed across the 000000-999999 range.
- **Fix:** Use `otp := fmt.Sprintf("%06d", (int(b[0])<<16|int(b[1])<<8|int(b[2])) % 1000000)` to properly modulo.

---

#### BUG-B05: `strconv.Atoi` Errors Silently Ignored in Logistics/Execution [Severity: MEDIUM]
- **Type:** Backend / Error Handling
- **Files:** [logistics_handler.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/logistics/handler/logistics_handler.go#L83), [execution_handler.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/execution/handler/execution_handler.go#L105)
- **Description:** Multiple handlers use `id, _ := strconv.Atoi(chi.URLParam(r, "id"))` discarding the error. If `id` is non-numeric, `Atoi` returns 0, which then queries the database with `id=0` instead of returning a 400 error.
- **Occurrences:** `GetVendor`, `AssignOrderManager`, `CreatePurchaseOrder`, `CreateInstallation`, `AssignInstaller`, `SyncUpdates`, `GetUpdates`, `Signoff`
- **Fix:** Check `err` from `strconv.Atoi` and return 400 for invalid IDs (as done correctly in IAM and HR modules).

---

#### BUG-B06: Missing `down.sql` for Seed Migration [Severity: LOW]
- **Type:** Backend / Database
- **Description:** Migration `000002_seed_default_iam.up.sql` has no corresponding `000002_seed_default_iam.down.sql` file. This means `migrate down` will fail at this step.
- **Fix:** Create a `000002_seed_default_iam.down.sql` that deletes the seeded users and roles.

---

#### BUG-B07: RabbitMQ Global Mutable State [Severity: MEDIUM]
- **Type:** Backend / Concurrency
- **File:** [rabbitmq.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/broker/rabbitmq.go#L12-L13)
- **Description:** `var Conn *amqp.Connection` and `var Channel *amqp.Channel` are package-level globals. AMQP channels are NOT safe for concurrent use. Multiple goroutines publishing simultaneously (e.g., WhatsApp notifications from logistics and execution handlers) can cause data races.
- **Fix:** Use a channel pool or mutex-protected publish, or create a channel per publish call.

---

#### BUG-B08: MinIO URL Points to Internal Docker Hostname [Severity: MEDIUM]
- **Type:** Backend / Configuration
- **File:** [minio.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/storage/minio.go#L46)
- **Description:** The `UploadFile` function constructs URLs using `Client.EndpointURL().Host`, which in Docker is `minio:9000`. This URL is not accessible from the Flutter frontend or browser. PDFs and uploaded files will have unreachable URLs.
- **Fix:** Use a configurable public base URL (e.g., `http://localhost:9001`) for generating client-facing file URLs.

---

### FRONTEND BUGS

#### BUG-F01: Login Bypasses PIN Flow [Severity: HIGH]
- **Type:** Frontend / Flow Error
- **File:** [auth_provider.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/features/auth/providers/auth_provider.dart#L130-L136)
- **Description:** On successful login, `sessionUnlocked` is set to `true` immediately. This means users bypass the PIN verification flow entirely. The FRONTEND_TESTING_GUIDE says users should be forced to enter their PIN on every cold boot, but login grants immediate full access.
- **Impact:** The entire Ghost Mode PIN architecture is bypassed on fresh login. Users go straight to the dashboard.
- **Fix:** Set `sessionUnlocked: false` on login, and only unlock via `verifyPin()`.

---

#### BUG-F02: No Input Validation on Login Form [Severity: MEDIUM]
- **Type:** Frontend / UI
- **File:** [login_screen.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/screens/auth/login_screen.dart#L25-L38)
- **Description:** The login form submits even with empty email/password fields. No `FormKey` or field validators are used.
- **Fix:** Add a `GlobalKey<FormState>` with validators on both fields.

---

#### BUG-F03: "Keep Me Signed In" Checkbox Does Nothing [Severity: LOW]
- **Type:** Frontend / UI
- **File:** [login_screen.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/screens/auth/login_screen.dart#L16)
- **Description:** The `_keepSignedIn` state variable is toggled but never used in any logic. It's purely decorative.
- **Fix:** Either implement session persistence based on this flag or remove the checkbox.

---

#### BUG-F04: Forgot Password Link Shows Static Message [Severity: LOW]
- **Type:** Frontend / UI
- **File:** [login_screen.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/screens/auth/login_screen.dart#L119-L122)
- **Description:** The "Forgot?" button shows a static SnackBar saying "Password reset is not configured yet." However, the backend has fully implemented `POST /api/v1/password/forgot` and `POST /api/v1/password/reset` with OTP via Redis.
- **Fix:** Create a proper Forgot Password dialog/screen that calls the backend endpoints.

---

#### BUG-F05: `sqflite` Not Compatible with Chrome/Web [Severity: HIGH]
- **Type:** Frontend / Platform
- **File:** [pubspec.yaml](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/pubspec.yaml#L43)
- **Description:** The `sqflite` package does not work on Flutter Web (Chrome). The frontend-to-do.md requires SQLite for offline caching. When testing on Chrome, any SQLite operations will throw `MissingPluginException`.
- **Fix:** Use `sqflite_common_ffi_web` for web support, or use IndexedDB for web and SQLite for mobile via a platform-specific abstraction.

---

#### BUG-F06: `image_picker` Camera Not Available on Web [Severity: MEDIUM]
- **Type:** Frontend / Platform
- **File:** [pubspec.yaml](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/pubspec.yaml#L46)
- **Description:** The `image_picker` package has limited web support (no camera, only gallery). Site update photo capture and expense receipt upload will not work as expected on Chrome.
- **Workaround:** On web, fall back to file input only.

---

#### BUG-F07: Missing Error Display in Auth Flows [Severity: MEDIUM]
- **Type:** Frontend / UI
- **Description:** When `login`, `setupPins`, or `verifyPin` throw exceptions, the `AuthNotifier` does `rethrow` but several screens don't have try-catch blocks with user-facing error messages (they rely on `UiFeedback.parsedError` only in login). PIN setup and PIN entry screens need proper error handling.

---

#### BUG-F08: Router Has Only 2 Routes [Severity: HIGH]
- **Type:** Frontend / Flow
- **File:** [router.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/core/routes/router.dart)
- **Description:** The GoRouter only defines `/` (AuthWrapper) and `/crm/lead/:id`. All other navigation within the app must be happening via the `MainShellScreen` with internal tab navigation, not via deep-linkable routes. This means most screens are not directly addressable via URL.
- **Impact:** Browser back/forward buttons won't work for internal navigation on Chrome. No deep linking support.

---

#### BUG-F09: `AuthWrapper` Used as Both Route and Widget [Severity: LOW]
- **Type:** Frontend / Architecture
- **File:** [main.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/main.dart#L40-L71)
- **Description:** `AuthWrapper` is defined in `main.dart` and used as the root route builder. It handles authentication state internally, which creates tight coupling between routing and auth state management. On web, this can cause flash-of-wrong-content.

---

#### BUG-F10: `verifyPin` Calls `checkAuthStatus` Redundantly [Severity: LOW]
- **Type:** Frontend / Logical
- **File:** [auth_provider.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/features/auth/providers/auth_provider.dart#L183)
- **Description:** After PIN verification, `checkAuthStatus()` is called which resets `sessionUnlocked` to `false` (line 77), then the next line sets it back to `true`. This causes a brief flash of the PIN entry screen before the main app appears.
- **Fix:** Don't call `checkAuthStatus()` inside `verifyPin()`. Directly update state with the new token claims.

---

#### BUG-F11: `cacheBootSyncProvider` Inside `AuthWrapper.build()` [Severity: MEDIUM]
- **Type:** Frontend / Performance
- **File:** [main.dart](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/frontend/lib/main.dart#L67)
- **Description:** `ref.watch(cacheBootSyncProvider)` is called inside the `build()` method. If this provider performs HTTP requests, it will re-trigger on every rebuild, potentially causing duplicate API calls.
- **Fix:** Use `ref.read()` or move the cache sync to a one-time initialization.

---

#### BUG-F12: No Loading States on Data Screens [Severity: MEDIUM]
- **Type:** Frontend / UI
- **Description:** Based on the frontend-to-do.md, many screens still use hardcoded dummy data instead of live API data. Screens that do fetch data need loading indicators and error states.

---

### FLOW / INTEGRATION BUGS

#### BUG-I01: Quote->Order Handoff Has No Idempotency [Severity: MEDIUM]
- **Type:** Flow / Integration
- **File:** [worker main.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/cmd/worker/main.go#L113-L144)
- **Description:** The `quote_approved` consumer uses `auto-ack=true`. If the order creation fails (e.g., DB constraint), the message is already acknowledged and lost. The order won't be created and there's no retry mechanism.
- **Fix:** Use manual acknowledgment (`auto-ack=false`) and only ack after successful order creation.

---

#### BUG-I02: WhatsApp Notifications Fire-and-Forget in Goroutines [Severity: LOW]
- **Type:** Flow / Backend
- **Files:** [logistics_handler.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/logistics/handler/logistics_handler.go#L241-L267), [contractor_handler.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/execution/handler/contractor_handler.go#L81-L96)
- **Description:** Both dispatch and check-in handlers launch goroutines with `context.Background()` to send WhatsApp notifications. If the API container shuts down during this goroutine, the notification is lost silently.
- **Note:** This was previously identified and RabbitMQ was introduced. The goroutines publish to RabbitMQ (which is correct), but the `context.Background()` is still used after the HTTP response is sent.

---

#### BUG-I03: Complaint Escalation Threshold Inconsistency [Severity: LOW]
- **Type:** Flow / Documentation
- **Description:** The `module_flows.md` says complaints escalate after 48 hours. The worker code uses `ComplaintEscalationDays = 3` (72 hours). Mismatch.

---

#### BUG-I04: Follow-Up Cancellation on Lead Loss Not Implemented [Severity: MEDIUM]
- **Type:** Flow / Backend
- **Description:** `module_flows.md` states: "If marked `lost`, the system automatically cancels all pending follow-ups for this lead." The `UpdateStatus` method in `lead_svc.go` only updates the lead status and sets `lost_reason`. There is no code to cancel follow-ups.
- **Fix:** Add a call to `followUpRepo.CancelByLeadID()` when status changes to `lost`.

---

#### BUG-I05: Order Status Not Updated After PO Creation [Severity: MEDIUM]
- **Type:** Flow / Backend
- **Description:** `module_flows.md` states orders transition to `partially_ordered` or `ready_for_dispatch` after POs are created. The `CreatePurchaseOrder` handler creates the PO but never updates the parent order's status.

---

#### BUG-I06: No Database Transaction in Quotation Creation [Severity: MEDIUM]
- **Type:** Flow / Backend
- **Description:** While `quotation_svc.go` comments say "transactional with line items" (line 78), it depends on the repository implementation. If line item insertion fails after the quotation header is created, the DB could be in an inconsistent state.

---

### SECURITY ISSUES

#### SEC-01: JWT Secret Hardcoded as "secret" [Severity: CRITICAL]
- **Type:** Security
- **File:** [.env](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/.env#L5)
- **Description:** `JWT_SECRET=secret` is trivially guessable. Anyone can forge valid JWTs.
- **Fix:** Use a cryptographically secure random string (32+ characters).

---

#### SEC-02: WhatsApp Token Committed to Repository [Severity: CRITICAL]
- **Type:** Security
- **File:** [.env](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/.env#L35)
- **Description:** A real WhatsApp API token is committed in the `.env` file which is tracked by git.
- **Fix:** Add `.env` to `.gitignore` and use `.env.example` with placeholder values.

---

#### SEC-03: No Rate Limiting on Authentication Endpoints [Severity: HIGH]
- **Type:** Security
- **Description:** Login, PIN verification, and password reset endpoints have no rate limiting. An attacker can brute-force PINs (only 10,000 combinations for 4-digit normal PIN).
- **Fix:** Add per-IP rate limiting middleware for auth endpoints.

---

#### SEC-04: Password Hash Returned in ListUsers [Severity: HIGH]
- **Type:** Security
- **File:** [iam_repository.go](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/internal/iam/repository/iam_repository.go#L106-L132)
- **Description:** The `ListUsers` query fetches `password_hash`, `pin_hash`, and `high_security_pin_hash`. While the DTO layer strips these in the response, they are unnecessarily loaded into memory. If a future endpoint accidentally serializes the model directly, hashes would leak.
- **Fix:** Exclude sensitive columns from list queries.

---

### DOCUMENTATION MISMATCHES

#### DOC-01: API Contract Uses "contacted" Status
- **File:** [api_contracts.md](file:///home/prateek/Documents/Spacesio%20Beryl/CRM/spacesioberyl_v1/system-v1/backend/api_contracts.md#L319-L324)
- **Description:** API contract shows `"status": "first_call"` in one place but the status name `contacted` does not appear in the valid enum at all.

---

#### DOC-02: Expense Endpoint Returns 201 Not Documented
- **Description:** The `Create Expense` endpoint returns HTTP 201 (Created) but the API contract doesn't specify response codes.

---

#### DOC-03: Frontend Testing Guide References Missing "Admin Leaves" Screen
- **File:** FRONTEND_TESTING_GUIDE.md line 73
- **Description:** References "Admin Leaves (if exposed in the UI)" but this screen may not be implemented yet.

---

## Environment Details

| Component | Version/Config |
|---|---|
| Go | 1.25+ |
| PostgreSQL | 17-alpine |
| Redis | 7-alpine |
| RabbitMQ | 3-management-alpine |
| MinIO | latest |
| Flutter SDK | ^3.5.0 |
| Docker Compose | Services all running |
| Host OS | Ubuntu Linux |
