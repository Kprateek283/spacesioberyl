package model

import "time"

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

type Installation struct {
	ID                      int        `json:"id" db:"id"`
	OrderID                 int        `json:"order_id" db:"order_id"`
	TechnicalManagerID      int        `json:"technical_manager_id" db:"technical_manager_id"`
	InstallerID             *int       `json:"installer_id" db:"installer_id"`
	AgreedInstallerPrice    *float64   `json:"agreed_installer_price" db:"agreed_installer_price"`
	StartDate               *time.Time `json:"start_date" db:"start_date"`
	EstimatedCompletionDate *time.Time `json:"estimated_completion_date" db:"estimated_completion_date"`
	Status                  string     `json:"status" db:"status"`
	InstallerJobStatus      string     `json:"installer_job_status" db:"installer_job_status"`
	InstallerAdvanceAmount  float64    `json:"installer_advance_amount" db:"installer_advance_amount"`
	InstallerFinalAmount    float64    `json:"installer_final_amount" db:"installer_final_amount"`
	ClientSignoffURL        *string    `json:"client_signoff_url" db:"client_signoff_url"`
	ClientFeedback          *string    `json:"client_feedback" db:"client_feedback"`
	CreatedAt               time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt               time.Time  `json:"updated_at" db:"updated_at"`
}

type InstallationUpdate struct {
	ID             int       `json:"id" db:"id"`
	InstallationID int       `json:"installation_id" db:"installation_id"`
	LoggedBy       int       `json:"logged_by" db:"logged_by"`
	UpdateTime     time.Time `json:"update_time" db:"update_time"`
	Notes          *string   `json:"notes" db:"notes"`
	PhotoURL       *string   `json:"photo_url" db:"photo_url"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
}

// InstallerDailyLog represents the 'installer_daily_logs' table
type InstallerDailyLog struct {
	ID                int        `json:"id" db:"id"`
	InstallationID    int        `json:"installation_id" db:"installation_id"`
	InstallerID       int        `json:"installer_id" db:"installer_id"`
	Date              time.Time  `json:"date" db:"date"`
	VerifiedBy        int        `json:"verified_by" db:"verified_by"`
	CheckInTime       *time.Time `json:"check_in_time" db:"check_in_time"`
	VerificationNotes *string    `json:"verification_notes" db:"verification_notes"`
	ProofPhotoURL     *string    `json:"proof_photo_url" db:"proof_photo_url"`
	CheckOutTime      *time.Time `json:"check_out_time" db:"check_out_time"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
}

// InstallerPayment represents the 'installer_payments' table
type InstallerPayment struct {
	ID                   int       `json:"id" db:"id"`
	InstallationID       int       `json:"installation_id" db:"installation_id"`
	InstallerID          int       `json:"installer_id" db:"installer_id"`
	ProcessedBy          int       `json:"processed_by" db:"processed_by"`
	Amount               float64   `json:"amount" db:"amount"`
	PaymentType          string    `json:"payment_type" db:"payment_type"`
	PaymentMode          string    `json:"payment_mode" db:"payment_mode"`
	TransactionReference *string   `json:"transaction_reference,omitempty" db:"transaction_reference"`
	PaidAt               time.Time `json:"paid_at" db:"paid_at"`
}

