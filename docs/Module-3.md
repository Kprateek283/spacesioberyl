### Module 3: CRM & Sales Pipeline - Architecture Overview

This module is the revenue engine. It tracks a lead from their first inquiry, enforces scheduled follow-ups, and handles the generation of official financial quotations before handing the project off to the Supply Chain team.

#### 1. PostgreSQL Schema Design

```sql
-- LEADS / ENQUIRIES
CREATE TABLE leads (
    id SERIAL PRIMARY KEY,
    client_name VARCHAR(255) NOT NULL,
    client_phone VARCHAR(50) NOT NULL,
    client_email VARCHAR(255),
    source VARCHAR(100), -- e.g., 'website', 'referral', 'walk-in'
    assigned_to INT REFERENCES users(id), -- Sales Rep
    
    -- The State Machine
    status VARCHAR(50) NOT NULL DEFAULT 'new', 
    -- Valid States: 'new', 'first_call', 'pdf_sent', 'sample_sent', 'site_visit', 'negotiation', 'finalized', 'lost'
    
    lost_reason TEXT, -- Required if status == 'lost'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- FOLLOW-UP SCHEDULER
CREATE TABLE follow_ups (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    created_by INT NOT NULL REFERENCES users(id),
    scheduled_for TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT, -- Instructions for the follow-up
    status VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'completed', 'missed'
    completed_at TIMESTAMP WITH TIME ZONE,
    outcome_notes TEXT, -- Mandatory logged outcome after the call/meeting
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- QUOTATIONS (Master Record)
CREATE TABLE quotations (
    id SERIAL PRIMARY KEY,
    lead_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    created_by INT NOT NULL REFERENCES users(id),
    
    subtotal DECIMAL(12, 2) NOT NULL,
    tax_amount DECIMAL(12, 2) NOT NULL,
    total_amount DECIMAL(12, 2) NOT NULL, -- subtotal + tax_amount
    
    -- Financial Terms
    payment_term_type VARCHAR(50) NOT NULL, 
    -- '100_advance', 'advance_and_post_install', 'custom_credit', 'po_based'
    payment_term_details JSONB, 
    
    status VARCHAR(50) NOT NULL DEFAULT 'draft', 
    -- 'draft', 'sent', 'client_approved', 'rejected'
    
    pdf_url TEXT, -- MinIO bucket URL
    is_custom_pdf BOOLEAN DEFAULT false, -- True if the rep uploaded a manual PDF
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- QUOTATION LINE ITEMS (Child Record)
CREATE TABLE quotation_line_items (
    id SERIAL PRIMARY KEY,
    quotation_id INT NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
    item_name VARCHAR(255) NOT NULL,
    description TEXT,
    quantity DECIMAL(10, 2) NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    total_price DECIMAL(12, 2) NOT NULL -- quantity * unit_price
);
```

---

#### 2. Go Models (Structs)

```go
package models

import (
	"time"
	"encoding/json"
)

// --- Lead Models ---
type Lead struct {
	ID          int        `json:"id" db:"id"`
	ClientName  string     `json:"client_name" db:"client_name"`
	ClientPhone string     `json:"client_phone" db:"client_phone"`
	ClientEmail *string    `json:"client_email" db:"client_email"`
	Source      *string    `json:"source" db:"source"`
	AssignedTo  *int       `json:"assigned_to" db:"assigned_to"`
	Status      string     `json:"status" db:"status"`
	LostReason  *string    `json:"lost_reason,omitempty" db:"lost_reason"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

type CreateLeadRequest struct {
	ClientName  string  `json:"client_name" validate:"required"`
	ClientPhone string  `json:"client_phone" validate:"required"`
	ClientEmail string  `json:"client_email"`
	Source      string  `json:"source"`
}

type UpdateLeadStatusRequest struct {
	Status     string `json:"status" validate:"required,oneof=new first_call pdf_sent sample_sent site_visit negotiation finalized lost"`
	LostReason string `json:"lost_reason"` // Required if Status == "lost"
}

// --- Follow-Up Models ---
type FollowUp struct {
	ID           int        `json:"id" db:"id"`
	LeadID       int        `json:"lead_id" db:"lead_id"`
	CreatedBy    int        `json:"created_by" db:"created_by"`
	ScheduledFor time.Time  `json:"scheduled_for" db:"scheduled_for"`
	Notes        *string    `json:"notes" db:"notes"`
	Status       string     `json:"status" db:"status"`
	CompletedAt  *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	OutcomeNotes *string    `json:"outcome_notes,omitempty" db:"outcome_notes"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
}

type CreateFollowUpRequest struct {
	LeadID       int    `json:"lead_id" validate:"required"`
	ScheduledFor string `json:"scheduled_for" validate:"required"` // ISO8601 string
	Notes        string `json:"notes"`
}

type CompleteFollowUpRequest struct {
	OutcomeNotes string `json:"outcome_notes" validate:"required"`
}

// --- Quotation Models ---
type Quotation struct {
	ID                 int             `json:"id" db:"id"`
	LeadID             int             `json:"lead_id" db:"lead_id"`
	CreatedBy          int             `json:"created_by" db:"created_by"`
	Subtotal           float64         `json:"subtotal" db:"subtotal"`
	TaxAmount          float64         `json:"tax_amount" db:"tax_amount"`
	TotalAmount        float64         `json:"total_amount" db:"total_amount"`
	PaymentTermType    string          `json:"payment_term_type" db:"payment_term_type"`
	PaymentTermDetails json.RawMessage `json:"payment_term_details" db:"payment_term_details"`
	Status             string          `json:"status" db:"status"`
	PdfURL             *string         `json:"pdf_url" db:"pdf_url"`
	IsCustomPdf        bool            `json:"is_custom_pdf" db:"is_custom_pdf"`
	CreatedAt          time.Time       `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time       `json:"updated_at" db:"updated_at"`
}

type CreateQuotationRequest struct {
	PaymentTermType    string                 `json:"payment_term_type" validate:"required"`
	PaymentTermDetails map[string]interface{} `json:"payment_term_details" validate:"required"`
	LineItems          []QuotationLineItem    `json:"line_items" validate:"required,min=1"`
	TaxRate            float64                `json:"tax_rate"`
	CustomPdfURL       *string                `json:"custom_pdf_url,omitempty"` // The escape hatch
}

type QuotationLineItem struct {
	ItemName    string  `json:"item_name" validate:"required"`
	Description string  `json:"description"`
	Quantity    float64 `json:"quantity" validate:"required,gt=0"`
	UnitPrice   float64 `json:"unit_price" validate:"required,gt=0"`
}
```

---

#### 3. API Contracts (Routes)

All routes are prefixed with `/api/v1/crm`.

##### **A. Leads Pipeline**
| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/leads` | Create a new lead/enquiry. | *Admin / Sales* |
| **GET** | `/leads` | List leads. Query params: `?status=`, `?assigned_to=` | *Admin / Sales* |
| **GET** | `/leads/:id` | Get full lead details, including nested array of its FollowUps & Quotations. | *Admin / Sales* |
| **PATCH**| `/leads/:id/assign` | Assign a lead to a sales rep. Payload: `{"assigned_to": int}`. | *Admin / Sales Manager* |
| **PATCH**| `/leads/:id/status` | Move lead through the State Machine. If moving to `lost`, requires `lost_reason`. | *Admin / Assigned Sales Rep* |

##### **B. Follow-Up Engine**
| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/followups` | Schedule a future follow-up for a lead. | *Admin / Assigned Sales Rep* |
| **GET** | `/followups/my-queue` | Get pending follow-ups for the logged-in user, ordered by `scheduled_for` ASC. | *Sales Rep* |
| **PATCH**| `/followups/:id/complete`| Mark follow-up as done. Mandatory `outcome_notes` required in payload. | *Assigned Sales Rep* |

##### **C. Quotations & Finance Terms**
| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/leads/:id/quotations`| Create a quote. Handles line-item math, DB insertion, and MinIO PDF logic. | *Sales / Admin* |
| **GET** | `/leads/:id/quotations`| Get quotation history for a specific lead. | *Sales / Admin / Accounts* |
| **PATCH**| `/quotations/:id/status`| Update quote status (`sent`, `client_approved`, `rejected`). | *Sales / Admin* |

---

#### 4. Core Business Logic & Background Workers

1.  **The MinIO PDF Fork (Execution Logic for `POST /leads/:id/quotations`):**
    *   Backend calculates `Quantity * Unit Price` for all array items to get the total.
    *   **If `custom_pdf_url` is provided:** The backend sets `is_custom_pdf = true` and saves the provided URL. It bypasses generation.
    *   **If `custom_pdf_url` is missing:** The backend sets `is_custom_pdf = false`, renders an HTML template using the line items, converts it to PDF, uploads it to the local MinIO bucket, and saves the generated MinIO URL to the database.
2.  **Follow-Up Enforcement (Cron Job):**
    *   A worker runs hourly checking `follow_ups` where `scheduled_for < NOW() - INTERVAL '24 hours'` AND `status = 'pending'`.
    *   It automatically marks these as `missed` to trigger Admin dashboard alerts.
3.  **Module 4 Handoff Trigger:**
    *   When `PATCH /quotations/:id/status` changes a quote to `client_approved`, the backend must automatically dispatch an internal event (or DB trigger) to push this project into the **Supply Chain** module, alerting the Accounts team to expect the advance payment and the Operations team to begin procurement.
