package dto

type CreateInstallerRequest struct {
	Name                 string  `json:"name" validate:"required"`
	Phone                string  `json:"phone" validate:"required"`
	ExpertiseArea        string  `json:"expertise_area"`
	StandardRate         int64   `json:"standard_rate"` // paise
	PreferredPaymentMode string  `json:"preferred_payment_mode"`
}

type CreateInstallationRequest struct {
	TechnicalManagerID int `json:"technical_manager_id" validate:"required"`
}

type AssignInstallerRequest struct {
	InstallerID             int     `json:"installer_id" validate:"required"`
	AgreedInstallerPrice    int64   `json:"agreed_installer_price"` // paise
	EstimatedCompletionDate string  `json:"estimated_completion_date"` // YYYY-MM-DD
}

type BulkSyncUpdatesRequest struct {
	Updates []SyncUpdateItem `json:"updates" validate:"required"`
}

type SyncUpdateItem struct {
	LocalID    string `json:"local_id"`    // Flutter's local DB ID for mapping
	UpdateTime string `json:"update_time" validate:"required"` // ISO8601 — trust client clock
	Notes      string `json:"notes"`
	PhotoURL   string `json:"photo_url"` // Pre-uploaded to MinIO
}

type SignoffRequest struct {
	ClientSignoffURL string `json:"client_signoff_url" validate:"required"` // MinIO URL of signature
	Status           string `json:"status" validate:"required"` // 'client_approved' or 'redo_required'
	ClientFeedback   string `json:"client_feedback"`
}

// ---------------------------------------------------------
// CONTRACTOR MANAGEMENT DTOs
// ---------------------------------------------------------

type UpdateInstallerJobStatusRequest struct {
	Status string `json:"status" validate:"required"`
	// Valid: assigned, accepted, advance_disbursed, en_route, on_site, in_progress,
	//        completed_pending_signoff, client_approved, payment_discharged
}

type InstallerCheckInRequest struct {
	VerificationNotes string `json:"verification_notes" validate:"required"` // Cannot be empty — accountability
	ProofPhotoURL     string `json:"proof_photo_url"`                        // Optional MinIO link
}

type InstallerCheckOutRequest struct {
	// Empty body — uses path param for job ID
}

type RecordInstallerPaymentRequest struct {
	Amount               int64   `json:"amount" validate:"required"` // paise
	PaymentType          string  `json:"payment_type" validate:"required"`  // 'advance' or 'final_discharge'
	PaymentMode          string  `json:"payment_mode" validate:"required"`  // 'cash', 'bank_transfer', 'upi'
	TransactionReference string  `json:"transaction_reference"`
}

type InstallerLedgerResponse struct {
	InstallationID   int     `json:"installation_id"`
	InstallerID      int     `json:"installer_id"`
	AgreedPrice      int64 `json:"agreed_price"`      // paise
	TotalAdvance     int64 `json:"total_advance"`     // paise
	TotalFinal       int64 `json:"total_final"`       // paise
	TotalPaid        int64 `json:"total_paid"`        // paise
	RemainingBalance int64 `json:"remaining_balance"` // paise
}

// ---------------------------------------------------------
// SHARED RESPONSE DTOs
// ---------------------------------------------------------

type BasicResponse struct {
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
}
