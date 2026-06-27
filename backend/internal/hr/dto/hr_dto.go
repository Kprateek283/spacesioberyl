package dto

// ---------------------------------------------------------
// ATTENDANCE DTOs
// ---------------------------------------------------------

type CheckInRequest struct {
	IsOverrideRequest bool   `json:"is_override_request"`
	OverrideReason    string `json:"override_reason"` // Required if is_override_request == true
}

type ResolveOverrideRequest struct {
	Status         string `json:"status" validate:"required"` // 'approved' or 'rejected'
	RejectedReason string `json:"rejected_reason"`            // Required if Status == 'rejected'
}

type AttendanceFilter struct {
	Date      string // YYYY-MM-DD
	StartDate string
	EndDate   string
}



// ---------------------------------------------------------
// EXPENSE DTOs
// ---------------------------------------------------------

type CreateExpenseRequest struct {
	Amount      float64 `json:"amount" validate:"required"`
	PersonPaid  string  `json:"person_paid" validate:"required"`
	Context     string  `json:"context" validate:"required"`
	ExpenseDate string  `json:"expense_date"` // YYYY-MM-DD, defaults to today
	ReceiptURL  string  `json:"receipt_url"`
}

// ---------------------------------------------------------
// SHARED RESPONSE DTOs
// ---------------------------------------------------------

type BasicResponse struct {
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}
