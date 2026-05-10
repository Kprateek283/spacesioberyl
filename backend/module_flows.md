# Module Flows & Architecture

This document describes the logical workflows both within individual modules (Intra-Module) and across boundaries (Inter-Module) within the Spacesio Beryl backend.

---

## 1. Intra-Module Flows

### HR: Attendance & Leaves
*   **Attendance:** 
    1. Employee clicks "Check-In" -> Backend verifies if `client_ip` matches office IP. 
    2. If match: logs attendance as `present`.
    3. If mismatch: flags as `off_site` and requires an `override_reason`.
    4. Employee clicks "Check-Out" -> Updates the same daily record with the end time.
*   **Leaves (State Machine):**
    1. Employee requests leave -> State: `pending`.
    2. While `pending`, employee can edit or cancel.
    3. Admin approves/rejects -> State becomes immutable to the user.

### CRM: Lead to Quotation
1.  **Lead Capture:** New lead is created with state `new`.
2.  **Pipeline Movement:** Sales reps drag cards, triggering `PATCH /status` to move to `contacted`, `negotiation`, etc.
3.  **Quotation Generation:** A dynamic quote is built. Cash payment terms are hidden unless the user has `ghost_mode: true`.
4.  **Quote Approval:** Client agrees -> Quotation status is updated to `approved`.

### Execution: Site Installation
1.  **Contractor Assignment:** A job is created, and an external contractor is assigned with an agreed rate.
2.  **Daily Verification:** The internal Tech Manager logs the contractor's daily presence using `verification_notes`.
3.  **Offline Sync:** Tech Managers upload site photos and notes (buffered in SQLite on the frontend, sent to the backend when online).

---

## 2. Inter-Module Flows (Event-Driven)

To prevent monolithic spaghetti code, modules communicate via asynchronous RabbitMQ events when crossing domain boundaries.

### Event: `quote_approved` (CRM -> Logistics)
*   **Trigger:** When a Sales Rep marks a Quotation as `client_approved` in the CRM.
*   **Action:** The CRM module publishes a `quote_approved` event to RabbitMQ.
*   **Consumer:** The Logistics worker listens for this event. It parses the quotation data and automatically creates a new `Order` record in the Logistics database. This signals the Operations team to begin procurement and scheduling without requiring a manual handover meeting.

### Event: `installation_signoff` (Execution -> Accounts)
*   **Trigger:** When a Tech Manager submits the `ClientSignoff` (including the digital signature PNG) in the Execution module.
*   **Action:** The Execution module validates the signature and publishes an `installation_signoff` event.
*   **Consumer:** The worker catches this event and alerts the Accounts department.
*   **Constraint (Financial Lock):** The system strictly forbids releasing the "Final Discharge" payment to external contractors *unless* this signoff event has successfully propagated and validated the client's signature.

---

## 3. Asynchronous Cron Workers

Background processes run on internal tickers to manage system health:
*   **Missed Follow-Ups:** Scans the CRM daily. Any scheduled follow-up older than 24 hours without completion notes is flagged as `missed`.
*   **Complaint Escalation:** Scans CRM Complaints. If a `high` priority complaint is untouched for 48 hours, it escalates notifications to Management.