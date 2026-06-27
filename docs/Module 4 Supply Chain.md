### Module 4: Supply Chain & Logistics - Architecture

We need three core entities here:
1.  **Vendors:** The directory of people you buy from.
2.  **Purchase Orders (Procurement):** Tying the line items from the finalized quote to specific vendors.
3.  **Dispatches:** Tracking the physical movement of goods, loading responsibilities, and assigning the Operations staff.

#### 1. PostgreSQL Schema Design
*(To be executed on your Supabase/PostgreSQL instance)*

```sql
-- VENDOR DIRECTORY --
CREATE TABLE vendors (
    id SERIAL PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    phone VARCHAR(50) NOT NULL,
    email VARCHAR(255),
    tax_id VARCHAR(100), -- GSTIN or equivalent
    default_payment_mode VARCHAR(50), -- 'bank_transfer', 'cheque', 'cash', 'upi'
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PROJECTS / ORDERS (The Handoff Entity) --
-- Created automatically when a Quotation is approved.
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    quotation_id INT NOT NULL REFERENCES quotations(id) ON DELETE RESTRICT,
    lead_id INT NOT NULL REFERENCES leads(id),
    operations_manager_id INT REFERENCES users(id), -- The Ops guy in charge
    status VARCHAR(50) NOT NULL DEFAULT 'procurement', 
    -- 'procurement', 'ready_to_dispatch', 'dispatched', 'delivered'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- PURCHASE ORDERS (What you are buying from Vendors) --
CREATE TABLE purchase_orders (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    vendor_id INT NOT NULL REFERENCES vendors(id),
    created_by INT NOT NULL REFERENCES users(id),
    total_amount DECIMAL(12, 2) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft',
    -- 'draft', 'issued', 'partially_received', 'fully_received'
    payment_status VARCHAR(50) NOT NULL DEFAULT 'unpaid',
    -- 'unpaid', 'partially_paid', 'paid'
    expected_delivery_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- DISPATCH TRACKING --
CREATE TABLE dispatches (
    id SERIAL PRIMARY KEY,
    order_id INT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    operations_staff_id INT NOT NULL REFERENCES users(id), -- Person on the ground
    
    loading_responsibility VARCHAR(50) NOT NULL, 
    -- 'company', 'vendor', 'client'
    
    transport_driver_name VARCHAR(255),
    transport_vehicle_no VARCHAR(100),
    transport_phone VARCHAR(50),
    
    dispatch_time TIMESTAMP WITH TIME ZONE, -- Logged when truck leaves
    delivery_time TIMESTAMP WITH TIME ZONE, -- Logged when truck arrives/unloads
    
    status VARCHAR(50) NOT NULL DEFAULT 'scheduled',
    -- 'scheduled', 'in_transit', 'delivered', 'delayed'
    
    delivery_challan_url TEXT, -- MinIO URL for the signed delivery receipt
    notes TEXT,
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

// --- Vendor Models ---
type Vendor struct {
	ID                 int       `json:"id" db:"id"`
	CompanyName        string    `json:"company_name" db:"company_name"`
	ContactPerson      *string   `json:"contact_person" db:"contact_person"`
	Phone              string    `json:"phone" db:"phone"`
	Email              *string   `json:"email" db:"email"`
	TaxID              *string   `json:"tax_id" db:"tax_id"`
	DefaultPaymentMode *string   `json:"default_payment_mode" db:"default_payment_mode"`
	Address            *string   `json:"address" db:"address"`
	IsActive           bool      `json:"is_active" db:"is_active"`
	CreatedAt          time.Time `json:"created_at" db:"created_at"`
}

// --- Order Models (The Bridge) ---
type Order struct {
	ID                  int       `json:"id" db:"id"`
	QuotationID         int       `json:"quotation_id" db:"quotation_id"`
	LeadID              int       `json:"lead_id" db:"lead_id"`
	OperationsManagerID *int      `json:"operations_manager_id" db:"operations_manager_id"`
	Status              string    `json:"status" db:"status"`
	CreatedAt           time.Time `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time `json:"updated_at" db:"updated_at"`
}

// --- Dispatch Models ---
type Dispatch struct {
	ID                    int        `json:"id" db:"id"`
	OrderID               int        `json:"order_id" db:"order_id"`
	OperationsStaffID     int        `json:"operations_staff_id" db:"operations_staff_id"`
	LoadingResponsibility string     `json:"loading_responsibility" db:"loading_responsibility"`
	TransportDriverName   *string    `json:"transport_driver_name" db:"transport_driver_name"`
	TransportVehicleNo    *string    `json:"transport_vehicle_no" db:"transport_vehicle_no"`
	TransportPhone        *string    `json:"transport_phone" db:"transport_phone"`
	DispatchTime          *time.Time `json:"dispatch_time" db:"dispatch_time"`
	DeliveryTime          *time.Time `json:"delivery_time" db:"delivery_time"`
	Status                string     `json:"status" db:"status"`
	DeliveryChallanURL    *string    `json:"delivery_challan_url" db:"delivery_challan_url"`
	Notes                 *string    `json:"notes" db:"notes"`
}

type CreateDispatchRequest struct {
	OrderID               int    `json:"order_id" validate:"required"`
	OperationsStaffID     int    `json:"operations_staff_id" validate:"required"`
	LoadingResponsibility string `json:"loading_responsibility" validate:"required,oneof=company vendor client"`
	TransportDriverName   string `json:"transport_driver_name"`
	TransportVehicleNo    string `json:"transport_vehicle_no"`
	TransportPhone        string `json:"transport_phone"`
}

type UpdateDispatchTimestampRequest struct {
	Type        string `json:"type" validate:"required,oneof=dispatch delivery"` // Which timestamp to log
	ChallanURL  string `json:"challan_url"` // MinIO URL of photo taken by Ops staff upon delivery
	Notes       string `json:"notes"`
}
```

---

#### 3. API Contracts (Routes)

All routes are prefixed with `/api/v1/logistics`.

##### **A. Vendor Directory**
*(Highly suitable for Offline Caching in Flutter so Operations staff can call vendors without internet)*

| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/vendors` | Add a new vendor to the directory. | *Admin / Accounts / Ops* |
| **GET** | `/vendors` | List all active vendors. | *Authenticated User* |
| **GET** | `/vendors/:id` | Get specific vendor details. | *Authenticated User* |
| **PATCH**| `/vendors/:id` | Update vendor details or deactivate them. | *Admin / Accounts* |

##### **B. Orders & Procurement**

| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **GET** | `/orders` | List active orders. Ops team uses this as their primary dashboard. | *Ops / Admin* |
| **PATCH**| `/orders/:id/assign`| Assign an `operations_manager_id` to an order. | *Admin / Ops Manager* |
| **POST** | `/orders/:id/pos` | Create a Purchase Order linking a vendor to this order. | *Ops / Admin / Accounts* |

##### **C. Dispatch Tracking**
*(Crucial for Offline Support: Ops staff might be at a remote warehouse/site with bad network when the truck leaves/arrives)*

| Method | Route | Description | RBAC Requirement |
| :--- | :--- | :--- | :--- |
| **POST** | `/dispatches` | Create a dispatch plan (assigning vehicle, driver, and loading responsibility). | *Ops / Admin* |
| **GET** | `/dispatches/my-tasks`| Get dispatches assigned to the logged-in Operations staff member. | *Ops Staff* |
| **PATCH**| `/dispatches/:id/log` | Log exact `dispatch_time` or `delivery_time`. Updates status automatically. | *Ops Staff / Admin* |

---

#### 4. The "Module 3 to Module 4 Handoff" (Backend Event)

This is the most critical piece of business logic linking the systems:

When a Sales Rep or Admin calls `PATCH /api/v1/crm/quotations/:id/status` and changes the status to `client_approved`, your Go backend must execute a database transaction that does two things:
1.  Updates the Quotation status to `client_approved`.
2.  **Automatically executes an `INSERT INTO orders (quotation_id, lead_id) VALUES (...)`.**

This immediately creates a new record in the Operations Dashboard (`GET /api/v1/logistics/orders`). The Sales team is now officially "done" with the heavy lifting, and the Operations team gets an alert that they need to start assigning staff, procuring materials, and scheduling trucks.
