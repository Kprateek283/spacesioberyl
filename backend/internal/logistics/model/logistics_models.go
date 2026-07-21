package model

import "time"

// Vendor represents the 'vendors' table
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
	UpdatedAt          time.Time `json:"updated_at" db:"updated_at"`
}

// Order represents the 'orders' table (bridge from quotation to operations)
type Order struct {
	ID                  int       `json:"id" db:"id"`
	QuotationID         int       `json:"quotation_id" db:"quotation_id"`
	LeadID              int       `json:"lead_id" db:"lead_id"`
	OperationsManagerID *int      `json:"operations_manager_id" db:"operations_manager_id"`
	Status              string    `json:"status" db:"status"`
	PaymentTermType     *string   `json:"payment_term_type" db:"payment_term_type"`
	ClientName          string    `json:"client_name" db:"client_name"`
	CreatedAt           time.Time `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time `json:"updated_at" db:"updated_at"`
}

// PurchaseOrder represents the 'purchase_orders' table
type PurchaseOrder struct {
	ID                   int       `json:"id" db:"id"`
	OrderID              int       `json:"order_id" db:"order_id"`
	VendorID             int       `json:"vendor_id" db:"vendor_id"`
	CreatedBy            int       `json:"created_by" db:"created_by"`
	TotalAmount          int64     `json:"total_amount" db:"total_amount"` // paise
	Status               string    `json:"status" db:"status"`
	PaymentStatus        string    `json:"payment_status" db:"payment_status"`
	ExpectedDeliveryDate *time.Time `json:"expected_delivery_date" db:"expected_delivery_date"`
	CreatedAt            time.Time `json:"created_at" db:"created_at"`
}

// Dispatch represents the 'dispatches' table
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
	CreatedAt             time.Time  `json:"created_at" db:"created_at"`
}
