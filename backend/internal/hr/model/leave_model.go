package model

import "time"

// Leave represents the 'hr_leaves' table
type Leave struct {
	ID           int        `json:"id" db:"id"`
	UserID       int        `json:"user_id" db:"user_id"`
	LeaveType    string     `json:"leave_type" db:"leave_type"`
	StartDate    time.Time  `json:"start_date" db:"start_date"`
	EndDate      time.Time  `json:"end_date" db:"end_date"`
	Reason       string     `json:"reason" db:"reason"`
	Status       string     `json:"status" db:"status"`
	ApprovedBy   *int       `json:"approved_by" db:"approved_by"`
	AdminRemarks *string    `json:"admin_remarks" db:"admin_remarks"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}
