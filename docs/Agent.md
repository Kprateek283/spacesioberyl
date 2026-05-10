# Spacesio Beryl CRM & ERP - Backend Master Architecture

## Agent Directives (CRITICAL)
When operating in this repository, you must adhere strictly to the following rules:
1. **Minimal Disruption:** Only change the current code and architecture if absolutely needed. Do not rewrite working modules just to change the style.
2. **Backend Only:** Frontend will be done later. Focus entirely on Go, PostgreSQL, Redis, RabbitMQ, and MinIO integration.
3. **Pragmatic Design:** The code should not have too many abstractions. Make it intuitive, but strictly follow SOLID and DRY principles. Avoid deep interface nesting unless necessary for mocking/testing.
4. **Context Aware:** Read the existing codebase to understand the current progress, routing patterns, and database connections before implementing new features.
5. **Detailed Information:** Read the available docs to understand anything in detail.
6. **Clarification Required:** If a business rule or technical requirement is ambiguous, STOP and ask a question before writing code.

---

## 1. System Infrastructure
*   **Language:** Go (Golang)
*   **Database:** PostgreSQL (Relational truth)
*   **Cache & Cron Engine:** Redis
*   **Message Broker:** RabbitMQ (For decoupled event processing)
*   **File Storage:** MinIO (Local S3-compatible storage for PDFs, receipts, and site photos)
*   **Deployment:** On-premise via Docker Compose.

---

## 2. Core Architectural Patterns

### A. The "Ghost Mode" (Financial Cloaking)
*   **Concept:** The Super Admin has two PINs. A Standard PIN, and a High-Security PIN.
*   **Mechanism:** `POST /api/v1/iam/verify-pin` checks both hashes.
    *   If Standard PIN -> JWT includes claim `"ghost_mode": false`.
    *   If High-Security PIN -> JWT includes claim `"ghost_mode": true`.
*   **Enforcement:** All database repository methods fetching Quotations or Orders MUST check the context for `ghost_mode`. If `false`, the SQL query MUST append `WHERE payment_term_type != 'cash'`. Cash transactions do not exist to standard users.

### B. Offline-First Sync Support
*   Many field operations (Module 4 & 5) happen without internet.
*   The Go backend must provide bulk-sync endpoints (e.g., `/api/v1/execution/jobs/:id/updates/sync`) that accept arrays of timestamped events.
*   Backend must trust the `update_time` provided in the JSON payload (client's local clock) rather than the server's `NOW()`, while using `NOW()` for the `created_at` timestamp.

---

## 3. Module Breakdown & API Contracts

All endpoints must be protected by standard JWT middleware unless otherwise noted.

### Module 1: Identity & Access Management (IAM)
*Handles Authentication, RBAC, and Ghost Mode logic.*

*   **POST** `/api/v1/iam/login` -> Authenticates email/password, returns user state.
*   **POST** `/api/v1/iam/verify-pin` -> Validates PIN, returns JWT (handles Ghost Mode logic).
*   **POST** `/api/v1/iam/setup-pins` -> (Super Admin only) Sets Normal and High-Security PIN hashes.

### Module 2: Internal HR & Administration
*Handles daily office running.*

*   **POST** `/api/v1/hr/attendance/check-in` -> Requires `is_override_request` & `override_reason` if IP doesn't match office Wi-Fi.
*   **POST** `/api/v1/hr/attendance/check-out`
*   **PATCH** `/api/v1/hr/attendance/overrides/:id` -> Admin approves/rejects override. MUST require `rejected_reason` if rejecting.
*   **POST** `/api/v1/hr/complaints` -> Create internal tech support ticket. (Worker handles escalation if unresolved).
*   **POST** `/api/v1/hr/expenses` -> Log daily office expense (Amount, PersonPaid, Context, Date).

### Module 3: CRM & Sales Pipeline
*The state machine governing leads to finalized quotations.*

*   **POST** `/api/v1/crm/leads` -> Capture new inquiry.
*   **PATCH** `/api/v1/crm/leads/:id/status` -> Advance funnel. If `status == 'lost'`, requires `lost_reason`.
*   **POST** `/api/v1/crm/followups` -> Schedule next touchpoint.
*   **PATCH** `/api/v1/crm/followups/:id/complete` -> Requires `outcome_notes`.
*   **POST** `/api/v1/crm/leads/:id/quotations` -> **CRITICAL ROUTE.** 
    *   *Payload:* Payment Terms (Advance, Post-Install, Custom %, PO, Cash) and Line Items array.
    *   *Logic:* Calculates math. If `custom_pdf_url` is passed, saves it. Else, generates HTML->PDF, uploads to MinIO bucket, saves URL.
*   **PATCH** `/api/v1/crm/quotations/:id/status` -> If changed to `client_approved`, triggers RabbitMQ event to automatically create an `Order` in Module 4.

### Module 4: Supply Chain & Logistics
*Activated automatically when a quote is approved. Handles material movement.*

*   **GET** `/api/v1/logistics/vendors` -> Directory of suppliers (offline cached on frontend).
*   **GET** `/api/v1/logistics/orders` -> Operations dashboard.
*   **POST** `/api/v1/logistics/orders/:id/pos` -> Create Purchase Order linking vendor to specific order.
*   **POST** `/api/v1/logistics/dispatches` -> Assign vehicle, driver, and `loading_responsibility` (company/vendor/client).
*   **PATCH** `/api/v1/logistics/dispatches/:id/log` -> Log exact `dispatch_time` or `delivery_time`.

### Module 5: Field Execution & Installation
*The final mile. Strictly requires offline-sync capabilities.*

*   **GET** `/api/v1/execution/installers` -> Directory of external contractors.
*   **PATCH** `/api/v1/execution/jobs/:id/assign` -> Assign specific contractor, set negotiated price and estimated time.
*   **POST** `/api/v1/execution/jobs/:id/updates/sync` -> Accepts bulk array of offline-logged notes and MinIO photo URLs.
*   **PATCH** `/api/v1/execution/jobs/:id/signoff` -> **The Financial Lock.** 
    *   *Payload:* Client signature (MinIO URL) and status (`client_approved`).
    *   *Logic:* If approved, triggers backend event evaluating Quotation terms. Unlocks/Notifies Accounts team to collect final payment.

---

## 4. Background Workers & Event Triggers (RabbitMQ/Redis)
1.  **Complaint Escalator:** Runs daily. If `complaints.status != 'resolved'` and age > X days -> Escalate & Notify Admin.
2.  **Follow-Up Missed Trigger:** Runs hourly. If `follow_ups.scheduled_for` is past 24 hours -> Mark `missed`, flag Admin.
3.  **Module 3-to-4 Handoff:** Quote Approved -> Insert into `orders` table.
4.  **Module 5 Financial Lock:** Installation Approved -> Trigger Accounts Receivable notification based on Quote terms.
