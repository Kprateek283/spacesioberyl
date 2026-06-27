# Frontend Engineering Task List

This document outlines all bugs and tasks identified during the QA testing phase that fall under the scope of the frontend engineering team.

## Collaboration Required (Frontend + Backend)

#### BUG-B01: Lead Status Enum Mismatch [Severity: HIGH] - [FIXED]
- **Type:** Frontend / Backend Logic Alignment
- **Description:** The backend `validLeadStatuses` map uses `first_call` but the API contracts documentation lists `contacted` as a valid status. The frontend testing guide also references statuses inconsistent with what the backend accepts.
- **Valid statuses in backend:** `new, first_call, pdf_sent, sample_sent, site_visit, negotiation, finalized, lost`
- **Documented statuses:** `contacted, negotiation` (in `api_contracts.md`)
- **Impact:** Frontend forms sending `contacted` will receive 400 errors from the backend.
- **Fix:** Updated frontend filters and status chips to match backend enums perfectly.

---

## Core Frontend Bugs

#### BUG-F01: Login Bypasses PIN Flow [Severity: HIGH] - [FIXED]
- **Type:** Frontend / Flow Error
- **File:** `frontend/lib/features/auth/providers/auth_provider.dart`
- **Description:** On successful login, `sessionUnlocked` is set to `true` immediately. This bypasses the entire Ghost Mode PIN verification flow.
- **Fix:** Set `sessionUnlocked: false` upon successful standard login, and strictly require `verifyPin()` to unlock the session.

#### BUG-F02: No Input Validation on Login Form [Severity: MEDIUM] - [FIXED]
- **Type:** Frontend / UI
- **File:** `frontend/lib/screens/auth/login_screen.dart`
- **Description:** The login form submits even with empty email/password fields.
- **Fix:** Implemented a Flutter `GlobalKey<FormState>` and added validators to the TextFormFields.

#### BUG-F03: "Keep Me Signed In" Checkbox Does Nothing [Severity: LOW] - [FIXED]
- **Type:** Frontend / UI
- **File:** `frontend/lib/screens/auth/login_screen.dart`
- **Description:** The `_keepSignedIn` boolean is toggled but its value is never used to persist state.
- **Fix:** Removed the non-functional UI element.

#### BUG-F04: Forgot Password Link Shows Static Message [Severity: LOW] - [FIXED]
- **Type:** Frontend / UI
- **File:** `frontend/lib/screens/auth/login_screen.dart`
- **Description:** The "Forgot?" button triggers a static unimplemented SnackBar message, despite the backend having full OTP support.
- **Fix:** Built the Forgot Password and OTP Reset flow screens to interact with `POST /api/v1/password/forgot` and `reset`.

#### BUG-F05: `sqflite` Not Compatible with Chrome/Web [Severity: HIGH] - [FIXED]
- **Type:** Frontend / Platform
- **File:** `frontend/pubspec.yaml`
- **Description:** `sqflite` throws `MissingPluginException` on Flutter Web.
- **Fix:** Confirmed that `database_helper.dart` already implements in-memory caching for web (`kIsWeb`), effectively mitigating this issue.

#### BUG-F06: `image_picker` Camera Not Available on Web [Severity: MEDIUM] - [FIXED]
- **Type:** Frontend / Platform
- **File:** `frontend/pubspec.yaml`
- **Description:** `image_picker` lacks strong camera support on Chrome. Site updates and expense receipts cannot use direct camera capture.
- **Fix:** Implemented a graceful fallback to standard file/gallery selection when running on Web (`kIsWeb ? ImageSource.gallery : ImageSource.camera`).

#### BUG-F07: Missing Error Display in Auth Flows [Severity: MEDIUM] - [FIXED]
- **Type:** Frontend / UI
- **Description:** Various screens (like PIN setup) lack `try-catch` UI feedback mechanisms (e.g. `UiFeedback.parsedError`) when exceptions bubble up from `AuthNotifier`.
- **Fix:** Verified `try-catch` and `UiFeedback.parsedError` exist across PIN entry, PIN setup, login, and forgot password screens.

---

## Architecture & Routing

#### BUG-F08: Router Has Only 2 Routes [Severity: HIGH] - [FIXED]
- **Type:** Frontend / Flow
- **File:** `frontend/lib/core/routes/router.dart`
- **Description:** The `GoRouter` configuration lacks definitions for most internal screens. Navigation inside `MainShellScreen` is bypassing deep-linkable URLs.
- **Impact:** Breaks browser back/forward buttons and deep linking.
- **Fix:** Refactored router to use `ShellRoute` with properly nested paths for deep linking (`/crm`, `/logistics`, `/execution`, `/more`).

#### BUG-F09: `AuthWrapper` Used as Both Route and Widget [Severity: LOW] - [FIXED]
- **Type:** Frontend / Architecture
- **File:** `frontend/lib/main.dart`
- **Description:** Tight coupling between routing and auth state management can cause UI flashing on Web.
- **Fix:** Removed `AuthWrapper`. Authentication routing is now properly handled by GoRouter's `redirect` mechanism.

#### BUG-F10: `verifyPin` Calls `checkAuthStatus` Redundantly [Severity: LOW] - [FIXED]
- **Type:** Frontend / Logical
- **File:** `frontend/lib/features/auth/providers/auth_provider.dart`
- **Description:** Redundant checks cause brief flashes of the PIN entry screen during transitions.
- **Fix:** State changes are optimized and `checkAuthStatus()` is completely refactored.

#### BUG-F11: `cacheBootSyncProvider` Inside `AuthWrapper.build()` [Severity: MEDIUM] - [FIXED]
- **Type:** Frontend / Performance
- **File:** `frontend/lib/main.dart`
- **Description:** `ref.watch()` triggers on every build, potentially spamming backend sync endpoints.
- **Fix:** Switched to `ref.read()` inside `MainShellScreen` for a one-time boot sync execution.

#### BUG-F12: No Loading States on Data Screens [Severity: MEDIUM] - [FIXED]
- **Type:** Frontend / UI
- **Description:** Many screens transitioning from dummy data to live APIs lack loading indicators.
- **Fix:** Verified `CircularProgressIndicator` implementations in `admin_dashboard`, `crm_leads`, `crm_lead_detail`, `logistics_orders`, and `vendors_list`.

---

## Documentation

#### DOC-03: Frontend Testing Guide Mismatches - [FIXED]
- **Fix:** Updated `FRONTEND_TESTING_GUIDE.md` and aligned testing guide with the actually available screens and correct enums.
