# Frontend Engineering Task List

This document outlines all bugs and tasks identified during the QA testing phase that fall under the scope of the frontend engineering team.

## Collaboration Required (Frontend + Backend)

#### BUG-B01: Lead Status Enum Mismatch [Severity: HIGH]
- **Type:** Frontend / Backend Logic Alignment
- **Description:** The backend `validLeadStatuses` map uses `first_call` but the API contracts documentation lists `contacted` as a valid status. The frontend testing guide also references statuses inconsistent with what the backend accepts.
- **Valid statuses in backend:** `new, first_call, pdf_sent, sample_sent, site_visit, negotiation, finalized, lost`
- **Documented statuses:** `contacted, negotiation` (in `api_contracts.md`)
- **Impact:** Frontend forms sending `contacted` will receive 400 errors from the backend.
- **Fix:** Coordinate with the Backend engineer to decide on a single source of truth. Either the backend updates their enum, or the frontend must align its dropdowns and models to match the backend's strict list.

---

## Core Frontend Bugs

#### BUG-F01: Login Bypasses PIN Flow [Severity: HIGH]
- **Type:** Frontend / Flow Error
- **File:** `frontend/lib/features/auth/providers/auth_provider.dart`
- **Description:** On successful login, `sessionUnlocked` is set to `true` immediately. This bypasses the entire Ghost Mode PIN verification flow.
- **Fix:** Set `sessionUnlocked: false` upon successful standard login, and strictly require `verifyPin()` to unlock the session.

#### BUG-F02: No Input Validation on Login Form [Severity: MEDIUM]
- **Type:** Frontend / UI
- **File:** `frontend/lib/screens/auth/login_screen.dart`
- **Description:** The login form submits even with empty email/password fields.
- **Fix:** Implement a Flutter `GlobalKey<FormState>` and add validators to the TextFormFields.

#### BUG-F03: "Keep Me Signed In" Checkbox Does Nothing [Severity: LOW]
- **Type:** Frontend / UI
- **File:** `frontend/lib/screens/auth/login_screen.dart`
- **Description:** The `_keepSignedIn` boolean is toggled but its value is never used to persist state.
- **Fix:** Either implement session token persistence in `flutter_secure_storage` based on this flag, or remove the UI element.

#### BUG-F04: Forgot Password Link Shows Static Message [Severity: LOW]
- **Type:** Frontend / UI
- **File:** `frontend/lib/screens/auth/login_screen.dart`
- **Description:** The "Forgot?" button triggers a static unimplemented SnackBar message, despite the backend having full OTP support.
- **Fix:** Build the Forgot Password and OTP Reset flow screens to interact with `POST /api/v1/password/forgot` and `reset`.

#### BUG-F05: `sqflite` Not Compatible with Chrome/Web [Severity: HIGH]
- **Type:** Frontend / Platform
- **File:** `frontend/pubspec.yaml`
- **Description:** `sqflite` throws `MissingPluginException` on Flutter Web.
- **Fix:** Integrate `sqflite_common_ffi_web` for browser support, or conditionally use IndexedDB vs native SQLite based on the platform.

#### BUG-F06: `image_picker` Camera Not Available on Web [Severity: MEDIUM]
- **Type:** Frontend / Platform
- **File:** `frontend/pubspec.yaml`
- **Description:** `image_picker` lacks strong camera support on Chrome. Site updates and expense receipts cannot use direct camera capture.
- **Fix:** Implement a graceful fallback to standard file/gallery selection when running on Web.

#### BUG-F07: Missing Error Display in Auth Flows [Severity: MEDIUM]
- **Type:** Frontend / UI
- **Description:** Various screens (like PIN setup) lack `try-catch` UI feedback mechanisms (e.g. `UiFeedback.parsedError`) when exceptions bubble up from `AuthNotifier`.
- **Fix:** Add visual error handling to all authentication state screens.

---

## Architecture & Routing

#### BUG-F08: Router Has Only 2 Routes [Severity: HIGH]
- **Type:** Frontend / Flow
- **File:** `frontend/lib/core/routes/router.dart`
- **Description:** The `GoRouter` configuration lacks definitions for most internal screens. Navigation inside `MainShellScreen` is bypassing deep-linkable URLs.
- **Impact:** Breaks browser back/forward buttons and deep linking.
- **Fix:** Map out all primary views as proper `GoRoute` entries.

#### BUG-F09: `AuthWrapper` Used as Both Route and Widget [Severity: LOW]
- **Type:** Frontend / Architecture
- **File:** `frontend/lib/main.dart`
- **Description:** Tight coupling between routing and auth state management can cause UI flashing on Web.
- **Fix:** Decouple `AuthWrapper` into a standard redirect router logic or top-level shell.

#### BUG-F10: `verifyPin` Calls `checkAuthStatus` Redundantly [Severity: LOW]
- **Type:** Frontend / Logical
- **File:** `frontend/lib/features/auth/providers/auth_provider.dart`
- **Description:** Redundant checks cause brief flashes of the PIN entry screen during transitions.
- **Fix:** Optimize state changes to avoid unnecessary re-renders.

#### BUG-F11: `cacheBootSyncProvider` Inside `AuthWrapper.build()` [Severity: MEDIUM]
- **Type:** Frontend / Performance
- **File:** `frontend/lib/main.dart`
- **Description:** `ref.watch()` triggers on every build, potentially spamming backend sync endpoints.
- **Fix:** Move initialization to a one-time execution block or use `ref.read()`.

#### BUG-F12: No Loading States on Data Screens [Severity: MEDIUM]
- **Type:** Frontend / UI
- **Description:** Many screens transitioning from dummy data to live APIs lack loading indicators.
- **Fix:** Implement `CircularProgressIndicator` or skeleton loaders during API requests.

---

## Documentation

#### DOC-03: Frontend Testing Guide Mismatches
- **Fix:** Update `FRONTEND_TESTING_GUIDE.md` to reflect the actual screens implemented (e.g. clarify the status of the "Admin Leaves" screen).
