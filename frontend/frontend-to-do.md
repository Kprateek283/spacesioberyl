# Frontend Engineer Handover & To-Do List

Welcome to the Spacesio Beryl Flutter project! The backend infrastructure is fully built, tested, and documented. The core Flutter architecture (theme, routing, and state management) has been bootstrapped. 

This document serves as your definitive roadmap to bringing the UI to life and fully integrating it with the backend.

---

## Task 1: The Authentication & PIN Pipeline
The system utilizes a dual-PIN architecture designed to mask specific financial data (Ghost Mode). You need to finalize this pipeline in the UI.

1.  **Initial Login (`/login`):**
    *   Call `POST /api/v1/login`.
    *   Store the returned `access_token` and `refresh_token` securely using `flutter_secure_storage`.
2.  **Super Admin Initialization (`/pin-setup`):**
    *   If a user is a `super_admin` and no local PIN is found, force them to set up a Normal PIN and a High-Security PIN (`POST /api/v1/iam/setup-pins`).
3.  **Daily Entry (`/pin-entry`):**
    *   When the app cold-boots, if a token exists, prompt for a 4-6 digit PIN.
    *   Hit `POST /api/v1/iam/verify-pin` with the entered PIN.
    *   The backend will return a *new* JWT. If the High-Security PIN was used, the JWT will contain a `"ghost_mode": true` claim.
4.  **Ghost Mode State:**
    *   Use `jwt_decoder` and `Riverpod` (see `auth_provider.dart`) to decode the active token.
    *   **Crucial:** Wrap any UI dropdowns, text fields, or ledger rows that mention "Cash" in a boolean check against `authState.ghostMode`. If false, those UI elements must completely disappear.

---

## Task 2: Client-Side Caching (SQLite for GET Routes)
Field staff operate in areas with terrible cellular reception. Critical directory data must be available offline.

1.  **The Target Tables:**
    *   Logistics Vendors (`/api/v1/logistics/vendors`)
    *   Execution Installers (`/api/v1/execution/installers`)
    *   Active CRM Leads (Basic info for phone numbers).
2.  **The Fetch Strategy:**
    *   When the app boots and `connectivity_plus` reports a Wi-Fi or 4G connection, silently perform `GET` requests to these endpoints.
    *   Truncate and bulk-insert the JSON responses into the local SQLite tables (see `DatabaseHelper` in `database_helper.dart`).
3.  **The UI Implementation:**
    *   Screens like `LogisticsVendorsScreen` and `ExecutionContractorsScreen` should **never** await an HTTP GET request directly. They must *always* `SELECT * FROM vendors` via the local SQLite `DatabaseHelper`.

---

## Task 3: The Offline Sync Engine (Mutations)
When a field worker submits a form (POST/PATCH) with no network, the app must not freeze or throw a network error.

1.  **The Outbox Queue:**
    *   Any field-action (e.g., Swiping to log a Dispatch, Submitting a Site Update) should write a JSON payload to the SQLite `outbox_queue` table along with the target API endpoint and HTTP method.
2.  **The SyncNotifier (`sync_service.dart`):**
    *   A Riverpod `StateNotifier` is already listening to `connectivity_plus`.
    *   When the device comes back online, the service iterates through the `outbox_queue` and fires the Dio requests.
3.  **Your Task:**
    *   Extend the `SyncService` to handle **Multipart Files** (MinIO).
    *   If a user takes a photo offline (e.g., Site Update), save the local file path string to SQLite.
    *   When syncing, the `SyncService` must first upload the physical image to MinIO (`ApiClient.uploadFile`), extract the returned URL, inject it into the JSON payload, and *then* fire the `POST` request to the backend.

---

## Task 4: Complete API Integration (70+ Routes)
The API client (`ApiClient` using Dio) is configured with automatic token injection and 401 refresh logic.

1.  **The Blueprints:**
    *   Open `backend/api_contracts.md`. This is your bible. It contains the exact JSON structures the Go backend expects.
2.  **The Work:**
    *   Go through the wireframed screens in `lib/features/` and replace any remaining hardcoded dummy lists (like the CRM Kanban columns or Logistics Orders) with active `FutureBuilders` or Riverpod `AsyncValue` providers that fetch from the Dio client.
    *   Ensure all forms (Add Lead, Create PO, Record Payment) are hooked up to their respective `POST` or `PATCH` endpoints.

---

## Task 5: Hardware Integrations
1.  **Client Signoff Canvas:**
    *   The `ClientSignoffScreen` uses the `signature` package. Ensure that the canvas outputs a compressed PNG byte array and successfully uploads to the backend.
2.  **Camera/Image Picker:**
    *   Connect the `image_picker` package to the `AddSiteUpdateModal` and `LogExpenseModal` so staff can snap physical photos of sites and receipts.

