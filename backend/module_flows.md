# Module Flows & Comprehensive Business Logic

This document maps out the specific execution flows, state machines, and edge cases across the Spacesio Beryl CRM & ERP.

---

## 1. CRM: Lead & Sales Pipeline Scenarios

### Scenario A: Successful Conversion (Lead -> Order)
1. **Lead Creation:** A Walk-in lead is created (`status: new`).
2. **Follow-Up Scheduled:** Sales Rep schedules a site visit via `POST /crm/followups`.
3. **Follow-Up Completed:** Rep visits site, fills out outcome notes, marks follow-up complete. Lead moves to `site_visit`.
4. **Quotation Generated:** Rep generates a quote (`POST /crm/leads/:id/quotations`) with a 10% tax and "Advance + Post-Install" terms. Status: `pdf_sent`.
5. **Client Approval:** Client agrees. Rep hits `PATCH /crm/quotations/:id/status` to `client_approved`.
6. **Background Handoff:** RabbitMQ intercepts the `quote_approved` event and silently spins up a corresponding `Order` in the Logistics table.

### Scenario B: Lead Lost
1. **Lead Interaction:** Sales Rep realizes the client cannot afford the product.
2. **Status Update:** Rep calls `PATCH /crm/leads/:id/status` setting `status: lost`.
3. **Mandatory Check:** The backend strict validation kicks in—the request *must* contain `lost_reason` (e.g., "Budget constraints").
4. **Follow-Ups Cleared:** All pending follow-ups for this lead are automatically cancelled or hidden from daily task queues.

### Scenario C: Quotation Rejected
1. **Quote Sent:** Client reviews the PDF.
2. **Rejection:** Client rejects due to high price.
3. **Status Update:** Rep updates Quote status to `rejected`.
4. **Next Steps:** Lead returns to `negotiation` state. Rep generates a *new* quotation with a discount. The system maintains the history of the rejected quote for auditing.

---

## 2. HR: Attendance & Leave Scenarios

### Scenario A: Standard Office Attendance
1. **Check-In:** Employee arrives at office, connects to Wi-Fi. 
2. **API Call:** `POST /hr/attendance/check-in` payload contains the Office IP.
3. **Result:** Backend detects IP match, logs `check_in_time`, sets `status: present`.
4. **Edge Case (Double Tap):** If employee spams Check-In, the DB's `ON CONFLICT DO NOTHING` constraint silently drops the duplicate requests, preventing data corruption.

### Scenario B: Remote/Field Check-In
1. **Check-In:** Employee is at a client site.
2. **API Call:** `POST /hr/attendance/check-in` payload contains a cellular IP.
3. **Result:** IP mismatch. Status is set to `pending_override`. Employee is forced to provide an `override_reason`.
4. **Admin Approval:** Manager reviews the `pending_override` list and approves it, officially changing status to `off_site`.

### Scenario C: Leave Cancellation (State Machine)
1. **Request:** Employee requests Casual Leave (`status: pending`).
2. **Self-Cancel:** Employee changes their mind before approval. They call `PATCH /hr/leaves/:id` to modify dates or cancel.
3. **Admin Intervention:** Admin approves the leave (`status: approved`).
4. **Locked State:** Employee tries to cancel again. Backend rejects the request with `400 Bad Request` because the leave state has moved past `pending`. Only an Admin can revert it.

---

## 3. Logistics & Execution Scenarios

### Scenario A: Offline Dispatch Syncing
1. **Network Drop:** Driver arrives at an underground warehouse with zero cell reception.
2. **Action:** Driver clicks "Swipe to Log Delivery".
3. **Local Queue:** Flutter app saves the payload `{ type: delivery, timestamp: ... }` to the SQLite `outbox_queue`.
4. **Network Return:** Driver drives out of the warehouse. `connectivity_plus` detects 4G.
5. **Sync Flush:** `SyncService` immediately drains the queue, sending the payload to the backend. The UI global banner shows "Syncing 1 item...".

### Scenario B: The Financial Lock (Execution -> Accounts)
1. **Job Completion:** Carpenters finish assembling the furniture.
2. **Attempted Payment:** Accounts team tries to release the "Final Discharge" payment to the carpenter.
3. **Backend Block:** The API throws a `400 Bad Request: Cannot process final payment without client signoff.`
4. **Client Action:** Tech Manager hands the tablet to the client. Client physically signs the `SignaturePad`.
5. **Signoff API:** Frontend uploads PNG to MinIO, sends the URL to `PATCH /execution/jobs/:id/signoff`. Job status changes to `client_approved`.
6. **Payment Unlocked:** Accounts team re-attempts the payment. The API validates `client_approved` and processes the ledger transaction.