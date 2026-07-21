package service

import (
	"context"
	"errors"
	"time"

	"github.com/spacesioberyl/system-v1/internal/hr/dto"
	"github.com/spacesioberyl/system-v1/internal/hr/model"
	"github.com/spacesioberyl/system-v1/internal/hr/repository"
)

type LeaveService struct {
	repo *repository.LeaveRepository
}

func NewLeaveService(repo *repository.LeaveRepository) *LeaveService {
	return &LeaveService{repo: repo}
}

var validLeaveTypes = map[string]bool{
	"sick_leave":   true,
	"casual_leave": true,
	"unpaid_leave": true,
}

// Request creates a new leave request
func (s *LeaveService) Request(ctx context.Context, userID int, req dto.RequestLeaveRequest) (*model.Leave, error) {
	if !validLeaveTypes[req.LeaveType] {
		return nil, errors.New("leave_type must be one of: sick_leave, casual_leave, unpaid_leave")
	}
	if req.Reason == "" {
		return nil, errors.New("reason is required")
	}

	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		return nil, errors.New("invalid start_date format (expected YYYY-MM-DD)")
	}
	endDate, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		return nil, errors.New("invalid end_date format (expected YYYY-MM-DD)")
	}
	if endDate.Before(startDate) {
		return nil, errors.New("end_date must be on or after start_date")
	}

	leave := &model.Leave{
		UserID:    userID,
		LeaveType: req.LeaveType,
		StartDate: startDate,
		EndDate:   endDate,
		Reason:    req.Reason,
	}
	return s.repo.Create(ctx, leave)
}

// MyLeaves returns all leave records for the logged-in user
func (s *LeaveService) MyLeaves(ctx context.Context, userID int) ([]*model.Leave, error) {
	return s.repo.ListByUser(ctx, userID)
}

// ListAll returns all leaves for admin view, with optional status filter
func (s *LeaveService) ListAll(ctx context.Context, status string, limit, offset int) ([]*model.Leave, error) {
	return s.repo.ListAll(ctx, status, limit, offset)
}

// EditLeave allows a user to edit their pending leave request. Ownership and the
// pending-status requirement are enforced atomically in UserEdit's WHERE clause,
// so there is no separate read-then-write gate to race (backend-bugs #29).
func (s *LeaveService) EditLeave(ctx context.Context, leaveID, userID int, req dto.EditLeaveRequest) error {
	var startDate, endDate *time.Time
	if req.StartDate != "" {
		t, err := time.Parse("2006-01-02", req.StartDate)
		if err != nil {
			return errors.New("invalid start_date format")
		}
		startDate = &t
	}
	if req.EndDate != "" {
		t, err := time.Parse("2006-01-02", req.EndDate)
		if err != nil {
			return errors.New("invalid end_date format")
		}
		endDate = &t
	}

	return s.repo.UserEdit(ctx, leaveID, userID, startDate, endDate, req.Reason)
}

// Cancel allows a user to cancel their own pending leave request
func (s *LeaveService) Cancel(ctx context.Context, leaveID, userID int) error {
	return s.repo.Cancel(ctx, leaveID, userID)
}

// AdminEdit allows an admin to force-edit leave details at any status
func (s *LeaveService) AdminEdit(ctx context.Context, leaveID int, req dto.AdminEditLeaveRequest) error {
	if req.LeaveType != "" && !validLeaveTypes[req.LeaveType] {
		return errors.New("leave_type must be one of: sick_leave, casual_leave, unpaid_leave")
	}

	var startDate, endDate *time.Time
	if req.StartDate != "" {
		t, err := time.Parse("2006-01-02", req.StartDate)
		if err != nil {
			return errors.New("invalid start_date format")
		}
		startDate = &t
	}
	if req.EndDate != "" {
		t, err := time.Parse("2006-01-02", req.EndDate)
		if err != nil {
			return errors.New("invalid end_date format")
		}
		endDate = &t
	}

	return s.repo.AdminEdit(ctx, leaveID, req.LeaveType, startDate, endDate, req.Reason)
}

// ProcessLeave allows admin to approve/reject a leave request
func (s *LeaveService) ProcessLeave(ctx context.Context, leaveID, adminID int, req dto.ProcessLeaveRequest) error {
	valid := map[string]bool{"approved": true, "rejected": true}
	if !valid[req.Status] {
		return errors.New("status must be 'approved' or 'rejected'")
	}
	return s.repo.UpdateStatus(ctx, leaveID, req.Status, adminID, req.AdminRemarks)
}
