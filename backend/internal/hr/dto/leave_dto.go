package dto

// ---------------------------------------------------------
// LEAVE DTOs
// ---------------------------------------------------------

// RequestLeaveRequest is used by employees to request a new leave.
type RequestLeaveRequest struct {
	LeaveType string `json:"leave_type" validate:"required"` // 'sick_leave', 'casual_leave', 'unpaid_leave'
	StartDate string `json:"start_date" validate:"required"` // YYYY-MM-DD
	EndDate   string `json:"end_date" validate:"required"`   // YYYY-MM-DD
	Reason    string `json:"reason" validate:"required"`
}

// EditLeaveRequest is used by employees to edit a pending leave request.
type EditLeaveRequest struct {
	StartDate string `json:"start_date"` // YYYY-MM-DD
	EndDate   string `json:"end_date"`   // YYYY-MM-DD
	Reason    string `json:"reason"`
}

// AdminEditLeaveRequest allows admins to force-edit leave details at any time.
type AdminEditLeaveRequest struct {
	LeaveType string `json:"leave_type"` // Admin can change the leave type
	StartDate string `json:"start_date"` // YYYY-MM-DD
	EndDate   string `json:"end_date"`   // YYYY-MM-DD
	Reason    string `json:"reason"`
}

// ProcessLeaveRequest is used by admins to approve or reject a leave.
type ProcessLeaveRequest struct {
	Status       string `json:"status" validate:"required"` // 'approved' or 'rejected'
	AdminRemarks string `json:"admin_remarks"`
}
