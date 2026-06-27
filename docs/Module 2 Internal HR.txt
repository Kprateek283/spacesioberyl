### Module 2: Internal HR & Administration - Architecture

This module has three primary responsibilities:
1.  **Attendance:** A strict IP-fenced check-in/check-out system with an override workflow.
2.  **Complaints:** An internal ticketing system for the Technical team with automatic escalations.
3.  **Expense Ledger:** A simple but strict tracker for daily office expenditures.

#### 1. PostgreSQL Schema Design
*(To be executed on your Supabase/PostgreSQL instance)*

```sql
-- ATTENDANCE --
CREATE TABLE attendances (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    check_in_time TIMESTAMP WITH TIME ZONE,
    check_out_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL DEFAULT 'absent', -- 'present', 'absent', 'half_day', 'off_site', 'pending_override'
    ip_address VARCHAR(50),
    is_office_wifi BOOLEAN DEFAULT false,
    
    -- Override Request Data
    override_reason TEXT,
    override_status VARCHAR(50), -- 'pending', 'approved', 'rejected'
    override_rejected_reason TEXT,
    reviewed_by INT REFERENCES users(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Ensure a user only has one attendance record per day
    UNIQUE(user_id, date)
);

-- COMPLAINTS (Internal Support Tickets) --
CREATE TABLE complaints (
    id SERIAL PRIMARY KEY,
    created_by INT NOT NULL REFERENCES users(id),
    assigned_to INT REFERENCES users(id), -- Usually a Technical team member
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'open', -- 'open', 'in_progress', 'resolved', 'escalated'
    priority VARCHAR(50) NOT NULL DEFAULT 'medium', -- 'low', 'medium', 'high', 'critical'
    escalated_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- EXPENSES (Daily Office Ledger) --
CREATE TABLE office_expenses (
    id SERIAL PRIMARY KEY,
    logged_by INT NOT NULL REFERENCES users(id),
    amount DECIMAL(10, 2) NOT NULL,
    person_paid VARCHAR(255) NOT NULL, -- Who received the money
    context TEXT NOT NULL, -- What it was for
    expense_date DATE NOT NULL DEFAULT CURRENT_DATE,
    receipt_url TEXT, -- Optional link to uploaded receipt photo
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

#### 2. Go Models (Structs)

```go
package models

import (
	"time"
)

// Attendance Models
type Attendance struct {
	ID                     int        `json:"id" db:"id"`
	UserID                 int        `json:"user_id" db:"user_id"`
	Date                   string     `json:"date" db:"date"`
	CheckInTime            *time.Time `json:"check_in_time" db:"check_in_time"`
	CheckOutTime           *time.Time `json:"check_out_time" db:"check_out_time"`
	Status                 string     `json:"status" db:"status"`
	IPAddress              string     `json:"ip_address" db:"ip_address"`
	IsOfficeWifi           bool       `json:"is_office_wifi" db:"is_office_wifi"`
	OverrideReason         *string    `json:"override_reason,omitempty" db:"override_reason"`
	OverrideStatus         *string    `json:"override_status,omitempty" db:"override_status"`
	OverrideRejectedReason *string    `json:"override_rejected_reason,omitempty" db:"override_rejected_reason"`
	ReviewedBy             *int       `json:"reviewed_by,omitempty" db:"reviewed_by"`
	CreatedAt              time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at" db:"updated_at"`
}

type CheckInRequest struct {
    // Only needed if they are requesting an off-site override at check-in
	IsOverrideRequest bool   `json:"is_override_request"`
	OverrideReason    string `json:"override_reason"`
}

type ResolveOverrideRequest struct {
	Status         string `json:"status" validate:"required,oneof=approved rejected"` // 'approved' or 'rejected'
	RejectedReason string `json:"rejected_reason"` // Required if Status == 'rejected'
}

// Complaint Models
type Complaint struct {
	ID          int        `json:"id" db:"id"`
	CreatedBy   int        `json:"created_by" db:"created_by"`
	AssignedTo  *int       `json:"assigned_to" db:"assigned_to"`
	Title       string     `json:"title" db:"title"`
	Description string     `json:"description" db:"description"`
	Status      string     `json:"status" db:"status"`
	Priority    string     `json:"priority" db:"priority"`
	EscalatedAt *time.Time `json:"escalated_at" db:"escalated_at"`
	ResolvedAt  *time.Time `json:"resolved_at" db:"resolved_at"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at" db:"updated_at"`
}

type CreateComplaintRequest struct {
	Title       string `json:"title" validate:"required"`
	Description string `json:"description" validate:"required"`
	Priority    string `json:"priority" validate:"required,oneof=low medium high critical"`
}

type UpdateComplaintStatusRequest struct {
	Status string `json:"status" validate:"required,oneof=open in_progress resolved escalated"`
}

// Expense Models
type Expense struct {
	ID         int       `json:"id" db:"id"`
	LoggedBy   int       `json:"logged_by" db:"logged_by"`
	Amount     float64   `json:"amount" db:"amount"`
	PersonPaid string    `json:"person_paid" db:"person_paid"`
	Context    string    `json:"context" db:"context"`
	ExpenseDate string   `json:"expense_date" db:"expense_date"`
	ReceiptURL *string   `json:"receipt_url,omitempty" db:"receipt_url"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time `json:"updated_at" db:"updated_at"`
}

type CreateExpenseRequest struct {
	Amount     float64 `json:"amount" validate:"required,gt=0"`
	PersonPaid string  `json:"person_paid" validate:"required"`
	Context    string  `json:"context" validate:"required"`
	ExpenseDate string `json:"expense_date"` // YYYY-MM-DD
	ReceiptURL string  `json:"receipt_url"`
}
```

---

#### 3. API Contracts (Routes)

All routes are prefixed with `/api/v1/hr`.

##### **A. Attendance API**

| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/attendance/check-in` | Record a check-in. Backend automatically grabs the requester's IP and checks against the configured Office IP. If `is_override_request` is true, sets status to `pending_override`. | *Authenticated User* |
| **POST** | `/attendance/check-out` | Record a check-out for today's active attendance record. | *Authenticated User* |
| **GET** | `/attendance/me` | Get the logged-in user's attendance history (supports `?start_date` and `?end_date` queries). | *Authenticated User* |
| **GET** | `/attendance` | Get all attendance records for the company (supports `?date=` query). | *Admin / Super Admin* |
| **GET** | `/attendance/overrides` | List all attendance records currently stuck in `pending_override` status. | *Admin / Super Admin* |
| **PATCH**| `/attendance/overrides/:id` | Approve or reject an override request. **Business Logic:** If rejected, `rejected_reason` MUST be provided in the JSON body. | *Admin / Super Admin* |

##### **B. Complaints API (Internal Support)**

| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/complaints` | Create a new internal complaint/ticket. | *Authenticated User* |
| **GET** | `/complaints` | List complaints. Supports filters: `?status=open`, `?assigned_to=id`, `?created_by=id`. | *Authenticated User* |
| **GET** | `/complaints/:id` | Get details of a specific complaint. | *Authenticated User* |
| **PATCH**| `/complaints/:id/assign` | Assign a complaint to a specific user (usually Technical staff). Body requires `{"assigned_to": int}`. | *Admin / Super Admin* |
| **PATCH**| `/complaints/:id/status` | Update status (`in_progress`, `resolved`). | *Admin, Super Admin, or Assigned User* |

*Note on Offline/Background logic:* We will need a Go worker (or a cron job leveraging Redis) that runs daily. It will query: `WHERE status != 'resolved' AND created_at < NOW() - INTERVAL 'X days'`. It will automatically change those statuses to `escalated` and fire a notification.

##### **C. Expense Ledger API**

| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/expenses` | Log a new daily expense. | *Authenticated User* |
| **GET** | `/expenses` | List expenses. Supports filters: `?start_date`, `?end_date`, `?logged_by`. | *Admin / Super Admin / Accounts* |
| **GET** | `/expenses/:id` | Get details of a specific expense. | *Admin / Super Admin / Accounts* |

*(Note: Ordinary users can POST expenses, but typically only Admins or the Accounts department need to GET and review the entire ledger).*
