package dto

type CreateVendorRequest struct {
	CompanyName        string `json:"company_name" validate:"required"`
	ContactPerson      string `json:"contact_person"`
	Phone              string `json:"phone" validate:"required"`
	Email              string `json:"email"`
	TaxID              string `json:"tax_id"`
	DefaultPaymentMode string `json:"default_payment_mode"`
	Address            string `json:"address"`
}

type UpdateVendorRequest struct {
	CompanyName        *string `json:"company_name"`
	ContactPerson      *string `json:"contact_person"`
	Phone              *string `json:"phone"`
	Email              *string `json:"email"`
	TaxID              *string `json:"tax_id"`
	DefaultPaymentMode *string `json:"default_payment_mode"`
	Address            *string `json:"address"`
	IsActive           *bool   `json:"is_active"`
}

type AssignOrderManagerRequest struct {
	OperationsManagerID int `json:"operations_manager_id" validate:"required"`
}

type CreatePurchaseOrderRequest struct {
	VendorID             int     `json:"vendor_id" validate:"required"`
	TotalAmount          int64   `json:"total_amount" validate:"required"` // paise
	ExpectedDeliveryDate string  `json:"expected_delivery_date"`
}

type CreateDispatchRequest struct {
	OrderID               int    `json:"order_id" validate:"required"`
	OperationsStaffID     int    `json:"operations_staff_id" validate:"required"`
	LoadingResponsibility string `json:"loading_responsibility" validate:"required"` // company, vendor, client
	TransportDriverName   string `json:"transport_driver_name"`
	TransportVehicleNo    string `json:"transport_vehicle_no"`
	TransportPhone        string `json:"transport_phone"`
}

type LogDispatchTimestampRequest struct {
	Type       string `json:"type" validate:"required"` // "dispatch" or "delivery"
	ChallanURL string `json:"challan_url"`
	Notes      string `json:"notes"`
}

type BasicResponse struct {
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}
