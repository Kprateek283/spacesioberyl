package dto

// ---------------------------------------------------------
// CLIENT COMPLAINT DTOs (CRM Support)
// ---------------------------------------------------------

type CreateClientComplaintRequest struct {
	Title       string `json:"title" validate:"required"`
	Description string `json:"description" validate:"required"`
	Priority    string `json:"priority" validate:"required"` // 'low', 'medium', 'high', 'critical'
	LeadID      *int   `json:"lead_id"`                      // At least one of lead_id or order_id required
	OrderID     *int   `json:"order_id"`
	ClientName  string `json:"client_name"`  // Fallback if not tied to a lead/order
	ClientPhone string `json:"client_phone"` // Fallback contact number
}

type UpdateComplaintStatusRequest struct {
	Status string `json:"status" validate:"required"` // 'open', 'in_progress', 'resolved', 'escalated'
}

type AssignComplaintRequest struct {
	AssignedTo int `json:"assigned_to" validate:"required"`
}
