package dto

// ---------------------------------------------------------
// LEAD DTOs
// ---------------------------------------------------------

type CreateLeadRequest struct {
	ClientName  string `json:"client_name" validate:"required"`
	ClientPhone string `json:"client_phone" validate:"required"`
	ClientEmail string `json:"client_email"`
	Source      string `json:"source"`
}

type UpdateLeadStatusRequest struct {
	Status     string `json:"status" validate:"required"` // new, first_call, pdf_sent, sample_sent, site_visit, negotiation, finalized, lost
	LostReason string `json:"lost_reason"`                // Required if Status == "lost"
}

type AssignLeadRequest struct {
	AssignedTo int `json:"assigned_to" validate:"required"`
}

// ---------------------------------------------------------
// FOLLOW-UP DTOs
// ---------------------------------------------------------

type CreateFollowUpRequest struct {
	LeadID       int    `json:"lead_id" validate:"required"`
	ScheduledFor string `json:"scheduled_for" validate:"required"` // ISO8601 string
	Notes        string `json:"notes"`
}

type CompleteFollowUpRequest struct {
	OutcomeNotes string `json:"outcome_notes" validate:"required"`
}

// ---------------------------------------------------------
// QUOTATION DTOs
// ---------------------------------------------------------

type CreateQuotationRequest struct {
	PaymentTermType    string                 `json:"payment_term_type" validate:"required"`
	PaymentTermDetails map[string]interface{} `json:"payment_term_details"`
	LineItems          []LineItemInput        `json:"line_items" validate:"required"`
	TaxRate            float64                `json:"tax_rate"` // Per-quotation, entered manually by user
	CustomPdfURL       *string                `json:"custom_pdf_url,omitempty"`
}

type LineItemInput struct {
	ItemName    string  `json:"item_name" validate:"required"`
	Description string  `json:"description"`
	Quantity    float64 `json:"quantity" validate:"required"`   // count, not money
	UnitPrice   int64   `json:"unit_price" validate:"required"` // paise
}

type UpdateQuotationStatusRequest struct {
	Status string `json:"status" validate:"required"` // 'sent', 'client_approved', 'rejected'
}

// ---------------------------------------------------------
// SHARED RESPONSE DTOs
// ---------------------------------------------------------

type BasicResponse struct {
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}
