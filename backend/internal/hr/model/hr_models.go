package model

import "time"

// Attendance represents the 'attendances' table
type Attendance struct {
	ID                     int        `json:"id" db:"id"`
	UserID                 int        `json:"user_id" db:"user_id"`
	Date                   time.Time  `json:"date" db:"date"`
	CheckInTime            *time.Time `json:"check_in_time" db:"check_in_time"`
	CheckOutTime           *time.Time `json:"check_out_time" db:"check_out_time"`
	Status                 string     `json:"status" db:"status"`
	IPAddress              *string    `json:"ip_address" db:"ip_address"`
	IsOfficeWifi           bool       `json:"is_office_wifi" db:"is_office_wifi"`
	OverrideReason         *string    `json:"override_reason,omitempty" db:"override_reason"`
	OverrideStatus         *string    `json:"override_status,omitempty" db:"override_status"`
	OverrideRejectedReason *string    `json:"override_rejected_reason,omitempty" db:"override_rejected_reason"`
	ReviewedBy             *int       `json:"reviewed_by,omitempty" db:"reviewed_by"`
	CreatedAt              time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at" db:"updated_at"`
}


// Expense represents the 'office_expenses' table
type Expense struct {
	ID          int       `json:"id" db:"id"`
	LoggedBy    int       `json:"logged_by" db:"logged_by"`
	Amount      float64   `json:"amount" db:"amount"`
	PersonPaid  string    `json:"person_paid" db:"person_paid"`
	Context     string    `json:"context" db:"context"`
	ExpenseDate time.Time `json:"expense_date" db:"expense_date"`
	ReceiptURL  *string   `json:"receipt_url,omitempty" db:"receipt_url"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}
