You are absolutely right, and this is a critical real-world correction. Forcing external contractors (who might be daily-wage workers or independent teams) to download a proprietary app, log in, and share GPS is a massive friction point. It almost never works in practice.

Shifting this to a **"Manager-Verified" model** simplifies the field reality while keeping your database strictly organized. The internal Tech/Ops Manager acts as the dispatcher—they call the contractor, ask for a WhatsApp photo or verbal confirmation, and click the buttons on their own CRM dashboard to update the state.

Here is the revised standalone blueprint adapted for **Manual Verification by Internal Staff**.

***

# Feature Blueprint: External Contractor & Site Management (Manual Verification Model)

## 1. Overview & Objective
This sub-module provides granular control over external installers across multiple concurrent sites. Instead of relying on contractor-facing apps, **Internal Managers (Tech/Ops)** act as the source of truth. They verify contractor movements (En Route, On-Site) via phone calls or WhatsApp photos, and manually log these state changes in the CRM. It tightly manages the financial lifecycle (Negotiation -> Advance -> Work -> Client Signoff -> Final Discharge).

## 2. The Installer Lifecycle (The State Machine)
The state machine remains strict, but the *triggers* are now fired by the internal management employee.

**The Step-by-Step Flow:**
1.  **`assigned`**: Tech Manager assigns the contractor and logs the negotiated price.
2.  **`accepted`**: Manager calls contractor: "Can you do this for ₹X?" -> Manager clicks "Accept" on their behalf.
3.  **`advance_disbursed`**: Accounts releases a small advance (e.g., 10%) to the contractor. 
4.  **`en_route`**: Manager calls in the morning: "Are you leaving?" -> Logs `en_route`.
5.  **`on_site`**: Manager calls or receives a WhatsApp site photo: "We are here." -> Logs `on_site`.
6.  **`in_progress`**: Manager logs daily updates (potentially uploading photos sent by the contractor to MinIO).
7.  **`completed_pending_signoff`**: Contractor reports work is done.
8.  **`client_approved`**: Manager (or site supervisor) secures the client's signature/approval.
9.  **`payment_discharged`**: Accounts releases the final negotiated amount.

---

## 3. PostgreSQL Schema Updates
We remove the GPS tracking columns and replace them with `verified_by` and `verification_notes` to maintain accountability for *who* in your company confirmed the contractor's presence.

```sql
-- 1. UPDATE EXISTING TABLE: installations
ALTER TABLE installations 
ADD COLUMN installer_job_status VARCHAR(50) NOT NULL DEFAULT 'assigned',
-- States: 'assigned', 'accepted', 'advance_disbursed', 'en_route', 'on_site', 'in_progress', 'completed_pending_signoff', 'client_approved', 'payment_discharged'
ADD COLUMN installer_advance_amount DECIMAL(10, 2) DEFAULT 0.00,
ADD COLUMN installer_final_amount DECIMAL(10, 2) DEFAULT 0.00;


-- 2. NEW TABLE: Daily Attendance & Verification Logs
CREATE TABLE installer_daily_logs (
    id SERIAL PRIMARY KEY,
    installation_id INT NOT NULL REFERENCES installations(id) ON DELETE CASCADE,
    installer_id INT NOT NULL REFERENCES installers(id),
    
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    
    -- Accountability: Who verified they were there?
    verified_by INT NOT NULL REFERENCES users(id), 
    
    check_in_time TIMESTAMP WITH TIME ZONE,
    verification_notes TEXT, -- e.g., "Called at 9:30 AM, confirmed on site"
    proof_photo_url TEXT, -- Optional MinIO link if contractor WhatsApp'd a photo
    
    check_out_time TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(installation_id, installer_id, date) 
);


-- 3. NEW TABLE: Installer Payments (Tracking money going OUT to the contractor)
CREATE TABLE installer_payments (
    id SERIAL PRIMARY KEY,
    installation_id INT NOT NULL REFERENCES installations(id),
    installer_id INT NOT NULL REFERENCES installers(id),
    processed_by INT NOT NULL REFERENCES users(id), 
    
    amount DECIMAL(10, 2) NOT NULL,
    payment_type VARCHAR(50) NOT NULL, -- 'advance', 'final_discharge'
    payment_mode VARCHAR(50) NOT NULL, -- 'cash', 'bank_transfer', 'upi'
    transaction_reference VARCHAR(255), 
    
    paid_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

## 4. API Contracts

All routes are prefixed with `/api/v1/execution/contractors`.

### A. Progress Verification (Used by Internal Manager)
| Method | Route | Description | 
| :--- | :--- | :--- | 
| **PATCH** | `/jobs/:id/status` | Updates the `installer_job_status`. | 
| **POST** | `/jobs/:id/check-in` | Logs the daily arrival. **Payload requires `verification_notes`** (and optionally `proof_photo_url`) instead of GPS. Automatically ties the log to the logged-in Manager (`verified_by`). | 
| **POST** | `/jobs/:id/check-out` | Logs departure for the day. Updates `installer_daily_logs`. |

### B. Contractor Financials (Used by Accounts/Ops)
| Method | Route | Description | 
| :--- | :--- | :--- | 
| **POST** | `/jobs/:id/payments` | Record money given to the contractor. Payload: `amount`, `payment_type`, `payment_mode`. Automatically updates the `installations` advance/final totals. |
| **GET** | `/jobs/:id/ledger` | Returns the financial summary of this specific contractor job: Agreed Price, Total Paid, Remaining Balance. |

---

## 5. Core Business Logic & Triggers

Because we rely on humans to verify the status, the backend must enforce strict data-entry validation rules to ensure managers don't take shortcuts.

1. **The Advance Block:** 
   * If Accounts tries to call `POST /jobs/:id/payments` with `payment_type = 'advance'`, the backend ensures `installer_job_status` is at least `accepted`.
   * Upon success, the backend auto-advances the status to `advance_disbursed`.
2. **The Verification Enforcement:**
   * When a Manager calls `POST /jobs/:id/check-in`, the backend strictly requires the `verification_notes` string to be populated (e.g., "Confirmed via call"). It cannot be an empty string. This ensures accountability.
3. **The Final Discharge Lock (CRITICAL):**
   * If Accounts tries to call `POST /jobs/:id/payments` with `payment_type = 'final_discharge'`, the backend **blocks the transaction** unless `installations.status == 'client_approved'`. 
   * This guarantees that a contractor cannot receive their final payout until the physical client signature/approval document is logged in the CRM, protecting the company's cash flow.