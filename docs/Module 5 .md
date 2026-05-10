### Module 5: Field Execution & Installation - Architecture

This module manages:
1. **The Contractor Roster:** External installers you hire for specific jobs.
2. **Site Execution:** Tracking the timeline from "Site Prep" to "Finished".
3. **The Financial Lock:** The final client sign-off that automatically alerts the Accounts team to collect the remaining payment.

#### 1. PostgreSQL Schema Design
*(To be executed on your Supabase/PostgreSQL instance)*

```sql
-- INSTALLER DIRECTORY (External Contractors) --
CREATE TABLE installers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    phone VARCHAR(50) NOT NULL,
    expertise_area VARCHAR(255), -- e.g., 'Carpentry', 'Electrical', 'Plumbing'
    standard_rate DECIMAL(10, 2), -- Typical daily or hourly rate
    preferred_payment_mode VARCHAR(50), 
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- INSTALLATION JOBS --
-- This bridges the Order (Module 4) to the physical site work
CREATE TABLE installations (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    technical_manager_id INT NOT NULL REFERENCES users(id), -- Internal Staff overseeing
    installer_id INT REFERENCES installers(id), -- External Contractor
    
    agreed_installer_price DECIMAL(10, 2), -- What you negotiated for this specific job
    
    start_date DATE,
    estimated_completion_date DATE,
    
    status VARCHAR(50) NOT NULL DEFAULT 'assigned',
    -- 'assigned', 'in_progress', 'paused', 'client_approved', 'redo_required'
    
    -- The Financial Lock
    client_signoff_url TEXT, -- MinIO URL of the captured signature/form
    client_feedback TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- DAILY SITE UPDATES (Built for Offline Sync) --
CREATE TABLE installation_updates (
    id SERIAL PRIMARY KEY,
    installation_id INT NOT NULL REFERENCES installations(id) ON DELETE CASCADE,
    logged_by INT NOT NULL REFERENCES users(id),
    
    update_time TIMESTAMP WITH TIME ZONE NOT NULL, -- Captured from device clock, not server time
    notes TEXT,
    photo_url TEXT, -- MinIO URL
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

#### 2. Go Models (Structs)

```go
package models

import (
	"time"
)

// --- Installer Models ---
type Installer struct {
	ID                   int       `json:"id" db:"id"`
	Name                 string    `json:"name" db:"name"`
	Phone                string    `json:"phone" db:"phone"`
	ExpertiseArea        *string   `json:"expertise_area" db:"expertise_area"`
	StandardRate         *float64  `json:"standard_rate" db:"standard_rate"`
	PreferredPaymentMode *string   `json:"preferred_payment_mode" db:"preferred_payment_mode"`
	IsActive             bool      `json:"is_active" db:"is_active"`
	CreatedAt            time.Time `json:"created_at" db:"created_at"`
}

// --- Installation Job Models ---
type Installation struct {
	ID                      int        `json:"id" db:"id"`
	OrderID                 int        `json:"order_id" db:"order_id"`
	TechnicalManagerID      int        `json:"technical_manager_id" db:"technical_manager_id"`
	InstallerID             *int       `json:"installer_id" db:"installer_id"`
	AgreedInstallerPrice    *float64   `json:"agreed_installer_price" db:"agreed_installer_price"`
	StartDate               *string    `json:"start_date" db:"start_date"`
	EstimatedCompletionDate *string    `json:"estimated_completion_date" db:"estimated_completion_date"`
	Status                  string     `json:"status" db:"status"`
	ClientSignoffURL        *string    `json:"client_signoff_url" db:"client_signoff_url"`
	ClientFeedback          *string    `json:"client_feedback" db:"client_feedback"`
	CreatedAt               time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt               time.Time  `json:"updated_at" db:"updated_at"`
}

type AssignInstallationRequest struct {
	TechnicalManagerID      int     `json:"technical_manager_id" validate:"required"`
	InstallerID             int     `json:"installer_id"`
	AgreedInstallerPrice    float64 `json:"agreed_installer_price"`
	EstimatedCompletionDate string  `json:"estimated_completion_date"` // YYYY-MM-DD
}

// --- Site Update Models (Offline Ready) ---
type InstallationUpdate struct {
	ID             int       `json:"id" db:"id"`
	InstallationID int       `json:"installation_id" db:"installation_id"`
	LoggedBy       int       `json:"logged_by" db:"logged_by"`
	UpdateTime     time.Time `json:"update_time" db:"update_time"`
	Notes          string    `json:"notes" db:"notes"`
	PhotoURL       *string   `json:"photo_url" db:"photo_url"`
}

// Represents the payload Flutter sends when it regains internet
type BulkSyncUpdatesRequest struct {
	Updates []struct {
		LocalID    string `json:"local_id"` // Used by Flutter to map successes
		UpdateTime string `json:"update_time" validate:"required"` // ISO8601
		Notes      string `json:"notes"`
		PhotoURL   string `json:"photo_url"` // Pre-uploaded to MinIO
	} `json:"updates" validate:"required"`
}
```

---

#### 3. API Contracts (Routes)

All routes are prefixed with `/api/v1/execution`.

##### **A. Installer Directory**
*(Cached offline so Technical Managers can call contractors from the site).*

| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/installers` | Add a new contractor. | *Tech / Ops / Admin* |
| **GET** | `/installers` | List active contractors. | *Tech / Ops* |

##### **B. Installation Jobs**
| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **GET** | `/jobs` | List active installations. | *Tech / Admin* |
| **GET** | `/jobs/my-tasks`| Get sites assigned to the logged-in Tech Manager. | *Tech Staff* |
| **POST** | `/orders/:id/installation`| Convert a dispatched Order into an active Installation Job. | *Ops / Tech Admin* |
| **PATCH**| `/jobs/:id/assign` | Assign the specific contractor and finalize their price. | *Tech Manager* |

##### **C. Site Updates (The Offline Sync Engine)**
| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/jobs/:id/updates/sync`| **Crucial:** Accepts an array of updates. Flutter calls this when it detects a network connection, pushing all offline photos and notes at once. | *Tech Staff* |
| **GET** | `/jobs/:id/updates` | Fetch the timeline of a specific site. | *Admin / Tech* |

##### **D. The Financial Lock (Final Sign-off)**
| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **PATCH**| `/jobs/:id/signoff`| Submits the final client signature (MinIO URL) and status (`client_approved` or `redo_required`). | *Tech Staff* |

---

#### 4. Core Business Logic: The "Financial Lock" Trigger

This is where the entire system comes full circle. 

When a Technical Staff member is at the client's site, the client physically signs the screen (or a paper form that is photographed). The Flutter app uploads this to MinIO and calls `PATCH /jobs/:id/signoff` with the status `client_approved`.

**The Go Backend immediately executes the following transaction:**
1. Updates `installations.status = 'client_approved'`.
2. Queries the `quotations` table from Module 3 to check `payment_term_details`.
3. **If `payment_term_type` is `advance_and_post_install`:** The backend looks at the `post_install_percent` (e.g., 40%). It calculates 40% of the `total_amount` and automatically generates a "Pending Payment" task in the Accounts Team dashboard.
4. Alerts the Accounts Manager: *"Site X is approved. Final payment of ₹Y is unlocked for collection."*
5. Alerts the Operations Manager to release the final payment to the external Installer.

---

### We Have the Complete Blueprint

We have now designed a fully integrated, state-machine-driven, offline-capable ERP/CRM. 
*   **Module 1:** Secures the gates (IAM).
*   **Module 2:** Runs the office (HR).
*   **Module 3:** Closes the deal (Sales & Quotes).
*   **Module 4:** Moves the goods (Supply Chain).
*   **Module 5:** Finishes the job (Execution & Billing).
