# Comprehensive System Workflows & Feature Architecture

This document details every feature within the Spacesio Beryl backend, its purpose, its internal execution flow, and how it logically links to the next feature in the business lifecycle.

---

## 1. Identity & Access Management (IAM)

### Feature: Dual-PIN Authentication & Ghost Mode
*   **Purpose:** To secure access to the application and provide a hardware-level toggle for viewing sensitive (cash-based) financial records.
*   **Internal Flow:**
    1. Super Admin logs in via email/password (`POST /api/v1/login`) to receive a temporary token.
    2. System checks if PINs are set. If not, Super Admin sets Normal and High-Security PINs (`POST /api/v1/iam/setup-pins`).
    3. For daily use, users authenticate via PIN (`POST /api/v1/iam/verify-pin`).
    4. If the High-Security PIN is used, the backend injects `"ghost_mode": true` into the JWT payload.
*   **Logical Link:** This JWT is passed in the `Authorization` header to every other module. Modules like CRM (Quotations) and Execution (Payments) read this claim to conditionally hide or show cash transactions.

### Feature: User & Role Management
*   **Purpose:** To control who can access which parts of the ERP.
*   **Internal Flow:**
    1. Admin fetches user list (`GET /api/v1/users`).
    2. Admin creates a new user (`POST /api/v1/users`), assigning a specific role (e.g., `staff`, `admin`) and department (e.g., `sales`, `operations`).
*   **Logical Link:** Departments dictate task assignments. Sales staff get CRM follow-ups; Operations staff get Logistics dispatches.

---

## 2. CRM & Sales Pipeline

### Feature: Lead Management
*   **Purpose:** To track potential clients from initial contact to final sale.
*   **Internal Flow:**
    1. Lead is created (`POST /api/v1/crm/leads`) with status `new`.
    2. Sales Rep updates the status (`PATCH /api/v1/crm/leads/:id/status`) as the relationship progresses (`contacted`, `negotiation`).
*   **Edge Case (Lead Lost):** If marked `lost`, a mandatory `lost_reason` is required. The system automatically cancels all pending follow-ups for this lead.
*   **Logical Link:** Leads are the parent entity for Follow-ups, Quotations, and Complaints.

### Feature: Follow-ups
*   **Purpose:** To ensure Sales Reps never miss a scheduled interaction with a Lead.
*   **Internal Flow:**
    1. Rep schedules a follow-up (`POST /api/v1/crm/followups`). Status is `pending`.
    2. Rep completes the task, providing mandatory `outcome_notes` (`PATCH /api/v1/crm/followups/:id/complete`).
*   **Edge Case (Missed Tasks):** A background cron worker scans the database hourly. Any `pending` follow-up older than 24 hours is automatically flagged as `missed`, alerting management.

### Feature: Quotation Generation & Approval
*   **Purpose:** To formally propose pricing and terms to the Lead.
*   **Internal Flow:**
    1. Rep generates a quote (`POST /api/v1/crm/leads/:id/quotations`) including line items, tax, and payment terms. (Cash terms are blocked if `ghost_mode` is false).
    2. Status becomes `pdf_sent`.
    3. If rejected, status is `rejected` and the lead returns to negotiation.
    4. If accepted, status is updated to `client_approved`.
*   **Logical Link (The Handoff):** Marking a quote as `client_approved` triggers the `quote_approved` RabbitMQ event. This automatically creates an **Order** in the Logistics module.

### Feature: Client Complaints
*   **Purpose:** To handle post-sale support ticketing.
*   **Internal Flow:**
    1. A complaint is logged against a Lead or Order (`POST /api/v1/crm/complaints`).
    2. Status starts as `open`.
*   **Edge Case (Escalation):** A background cron worker monitors complaints. If a `high` priority complaint remains `open` for 48 hours, it is escalated to management.

---

## 3. Supply Chain & Logistics

### Feature: Order Management & Procurement
*   **Purpose:** To fulfill the approved CRM Quotations.
*   **Internal Flow:**
    1. Order is automatically created via the RabbitMQ `quote_approved` event (Status: `pending_po`).
    2. Ops team creates Purchase Orders (`POST /api/v1/logistics/orders/:id/pos`) linking to external Vendors.
    3. Order status updates to `partially_ordered` or `ready_for_dispatch`.
*   **Logical Link:** Once items are procured, the Order must be shipped to the client site via Dispatches.

### Feature: Dispatch & Delivery Tracking
*   **Purpose:** To track the physical movement of goods.
*   **Internal Flow:**
    1. Ops creates a dispatch plan (`POST /api/v1/logistics/dispatches`) assigning a driver and vehicle.
    2. Driver swipes to log departure (`PATCH /api/v1/logistics/dispatches/:id/log` with `type: dispatch`).
    3. Driver swipes to log arrival at site (`type: delivery`), optionally uploading a signed delivery challan.
*   **Edge Case (Offline Sync):** If the driver is in a dead zone, the frontend saves the timestamp to SQLite and syncs it when the network returns.
*   **Logical Link:** Once an Order is fully delivered, it becomes eligible to be converted into an **Installation Job** in the Execution module.

---

## 4. Field Execution & Installation

### Feature: Job & Contractor Assignment
*   **Purpose:** To manage external contractors installing the delivered products.
*   **Internal Flow:**
    1. Tech Admin creates an Installation Job from a delivered Order (`POST /api/v1/execution/orders/:id/installation`).
    2. Manager assigns an external installer from the directory, setting the negotiated price (`PATCH /api/v1/execution/jobs/:id/assign`).

### Feature: Manual Presence Verification (Check-In)
*   **Purpose:** To prevent GPS spoofing by external contractors.
*   **Internal Flow:**
    1. Internal Tech Manager physically verifies the contractor is on site or calls them.
    2. Manager logs the verification (`POST /api/v1/execution/contractors/jobs/:id/check-in`), providing mandatory `verification_notes` (e.g., "Confirmed via WhatsApp").

### Feature: Site Updates
*   **Purpose:** To maintain a visual timeline of installation progress.
*   **Internal Flow:**
    1. Tech Manager captures photos and notes on-site.
    2. Sent via `POST /api/v1/execution/jobs/:id/updates/sync` (Supports offline queuing).

### Feature: Client Signoff & The Financial Lock
*   **Purpose:** To ensure client satisfaction before releasing final payments to external contractors.
*   **Internal Flow:**
    1. Installation finishes. Client physically signs the tablet.
    2. Signature PNG is uploaded to MinIO.
    3. URL is submitted via `PATCH /api/v1/execution/jobs/:id/signoff`. Job becomes `client_approved`.
*   **Logical Link:** The Accounts module attempts to pay the contractor (`POST /api/v1/execution/contractors/jobs/:id/payments`). If the payment type is `final_discharge`, the API strictly checks if the job is `client_approved`. If not, the payment is blocked.

---

## 5. Internal HR & Administration

### Feature: Strict Attendance
*   **Purpose:** To log employee work hours.
*   **Internal Flow:**
    1. Employee clicks Check-In (`POST /api/v1/hr/attendance/check-in`).
    2. Backend checks IP. If matched to office, status is `present`.
    3. If IP mismatches, status is `pending_override`. Manager must approve.
    4. Employee clicks Check-Out (`POST /api/v1/hr/attendance/check-out`).
*   **Edge Case:** The database uses `ON CONFLICT DO NOTHING` to prevent users from checking in multiple times a day.

### Feature: Leave State Machine
*   **Purpose:** To handle employee time-off requests securely.
*   **Internal Flow:**
    1. Employee requests leave (`POST /api/v1/hr/leaves`). Status: `pending`.
    2. While `pending`, employee can modify or cancel it.
    3. Admin reviews and updates status to `approved` or `rejected` with remarks (`PATCH /api/v1/hr/leaves/:id/status`).
*   **Edge Case:** Once the status moves past `pending`, the frontend and backend strictly block the employee from editing or cancelling the leave.

### Feature: Office Expenses
*   **Purpose:** To track petty cash and internal ledger items.
*   **Internal Flow:**
    1. Employee uploads receipt photo to MinIO.
    2. Employee submits expense amount and context (`POST /api/v1/hr/expenses`).
