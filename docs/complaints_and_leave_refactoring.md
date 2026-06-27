# Feature Blueprint: CRM Support & HR Leave Management

## Part 1: Refactoring Complaints (Internal IT -> Client Support)

### The Problem
Currently, the complaints system is routed under the HR module (`/api/v1/hr/complaints`). It was structured like an internal IT ticketing system (e.g., "The office AC is broken"). However, the real business need is to track **External Client Complaints** (e.g., "The kitchen hinges are loose after installation"). The current database lacks any connection to the actual client, lead, or order.

### The Solution
We will physically move the routing from the HR module to the CRM module (`/api/v1/crm/complaints`). We will update the database to tie every complaint to an existing `lead_id` or `order_id`. The RabbitMQ escalation worker will remain exactly the same, but now it will alert the Super Admin if a *client* is left waiting for more than 48 hours.

### 1. PostgreSQL Schema Updates
We need to rename the table and add relationships to the CRM tables.

```sql
-- 1. Rename the table to reflect external clients
ALTER TABLE hr_complaints RENAME TO client_complaints;

-- 2. Add relational columns
ALTER TABLE client_complaints 
ADD COLUMN lead_id INT REFERENCES leads(id),
ADD COLUMN order_id INT REFERENCES orders(id), -- If the complaint is post-installation
ADD COLUMN client_name VARCHAR(255), -- Fallback if not tied to an order yet
ADD COLUMN client_phone VARCHAR(20);
```

### 2. Updated API Contracts (CRM Support)
*All routes are now prefixed with `/api/v1/crm/complaints`*

| Method | Route | Description |
| :--- | :--- | :--- |
| **POST** | `/` | Creates a new client complaint. Payload must now include `lead_id` or `order_id`. |
| **GET** | `/` | Lists all active client complaints for the Support/Sales team. |
| **PATCH** | `/:id/assign` | Tech manager assigns the complaint to a specific field technician. |
| **PATCH** | `/:id/status` | Tech updates status to `resolved` (stops the RabbitMQ escalation timer). |

---

## Part 2: New Sub-Module: HR Leave Management

### The Problem
The current HR module tracks physical attendance via Office Wi-Fi and Check-In/Out buttons. However, there is no way for an employee to request future time off (Sick Leave, Casual Leave, Vacation), nor is there a way for management to approve, track, or edit these absences. 

### The Solution
We will introduce a `hr_leaves` table and a strict state machine (`pending` -> `approved` / `rejected`). 
To meet your specific requirement, both the User and the Admin can **Edit** the details of the leave (dates, reason), but with distinct business logic:
*   **Users** can only edit the dates/info of their leave if the status is still `pending`.
*   **Admins** can edit the dates/info at any time, and are the only ones who can change the `status`.

### 1. PostgreSQL Schema
```sql
CREATE TABLE hr_leaves (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    leave_type VARCHAR(50) NOT NULL, -- 'sick_leave', 'casual_leave', 'unpaid_leave'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'cancelled'
    
    approved_by INT REFERENCES users(id), -- The Admin who processed it
    admin_remarks TEXT, -- e.g., "Approved, but please ensure project X is handed over"
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### 2. API Contracts (HR Leaves)
*All routes are prefixed with `/api/v1/hr/leaves`*

#### For the Employee (User)
| Method | Route | Description |
| :--- | :--- | :--- |
| **POST** | `/` | **Request Leave:** Payload includes `start_date`, `end_date`, `leave_type`, and `reason`. Status defaults to `pending`. |
| **GET** | `/me` | **My Leaves:** Returns the logged-in user's leave history and current balances. |
| **PATCH** | `/:id` | **Edit Leave Info:** User can update dates or reason. **Backend Logic:** Fails if status is not `pending`. |
| **PATCH** | `/:id/cancel` | **Cancel Leave:** User cancels their own request. Changes status to `cancelled`. |

#### For the Management (Admin/HR)
| Method | Route | Description |
| :--- | :--- | :--- |
| **GET** | `/` | **List All Leaves:** Fetches company-wide leave requests. Can filter by `?status=pending`. |
| **PATCH** | `/:id/admin-edit` | **Admin Edit Info:** Admin forcefully changes the dates or leave type of an employee's request. |
| **PATCH** | `/:id/status` | **Process Leave:** Admin approves or rejects. Payload: `status` ('approved'/'rejected') and optional `admin_remarks`. Automatically logs `approved_by` as the logged-in admin. |