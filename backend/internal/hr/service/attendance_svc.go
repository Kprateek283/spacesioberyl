package service

import (
	"context"
	"errors"
	"net"

	"github.com/spacesioberyl/system-v1/internal/hr/dto"
	"github.com/spacesioberyl/system-v1/internal/hr/model"
	"github.com/spacesioberyl/system-v1/internal/hr/repository"
)

type AttendanceService struct {
	repo     *repository.AttendanceRepository
	officeIP string // Configured via env: OFFICE_IP
}

func NewAttendanceService(repo *repository.AttendanceRepository, officeIP string) *AttendanceService {
	return &AttendanceService{repo: repo, officeIP: officeIP}
}

// CheckIn records attendance, checking if the requester's IP matches the office network.
// If not on office WiFi, the user MUST explicitly set is_override_request=true with a reason.
func (s *AttendanceService) CheckIn(ctx context.Context, userID int, clientIP string, req dto.CheckInRequest) (*model.Attendance, error) {
	isOfficeWifi := s.isOfficeNetwork(clientIP)

	// If not on office WiFi and not requesting an override, reject
	if !isOfficeWifi && !req.IsOverrideRequest {
		return nil, errors.New("you are not on the office network. Set is_override_request=true with a reason to request an override")
	}

	// If requesting override, reason is mandatory
	if req.IsOverrideRequest && req.OverrideReason == "" {
		return nil, errors.New("override_reason is required when requesting an override")
	}

	return s.repo.CheckIn(ctx, userID, clientIP, isOfficeWifi, req.IsOverrideRequest, req.OverrideReason)
}

// CheckOut records the check-out time for today
func (s *AttendanceService) CheckOut(ctx context.Context, userID int) (*model.Attendance, error) {
	return s.repo.CheckOut(ctx, userID)
}

// GetMyAttendance returns the logged-in user's attendance with optional date range
func (s *AttendanceService) GetMyAttendance(ctx context.Context, userID int, startDate, endDate string) ([]*model.Attendance, error) {
	return s.repo.GetMyAttendance(ctx, userID, startDate, endDate)
}

// ListAll returns all attendance records (admin view) with optional date filter
func (s *AttendanceService) ListAll(ctx context.Context, date string, limit, offset int) ([]*model.Attendance, int, error) {
	return s.repo.ListAll(ctx, date, limit, offset)
}

// ListPendingOverrides returns attendance records awaiting admin approval
func (s *AttendanceService) ListPendingOverrides(ctx context.Context) ([]*model.Attendance, error) {
	return s.repo.ListPendingOverrides(ctx)
}

// ResolveOverride approves or rejects a pending override.
// If rejecting, a rejected_reason MUST be provided.
func (s *AttendanceService) ResolveOverride(ctx context.Context, attendanceID, reviewerID int, req dto.ResolveOverrideRequest) error {
	if req.Status != "approved" && req.Status != "rejected" {
		return errors.New("status must be 'approved' or 'rejected'")
	}
	if req.Status == "rejected" && req.RejectedReason == "" {
		return errors.New("rejected_reason is required when rejecting an override")
	}
	return s.repo.ResolveOverride(ctx, attendanceID, reviewerID, req.Status, req.RejectedReason)
}

// isOfficeNetwork checks if the client IP matches the configured office IP or CIDR range.
// Supports both exact IP match and CIDR notation (e.g., "192.168.1.0/24").
func (s *AttendanceService) isOfficeNetwork(clientIP string) bool {
	if s.officeIP == "" || s.officeIP == "0.0.0.0" {
		// Development mode: treat all IPs as office network
		return true
	}

	// Try CIDR match first
	_, network, err := net.ParseCIDR(s.officeIP)
	if err == nil {
		ip := net.ParseIP(clientIP)
		return ip != nil && network.Contains(ip)
	}

	// Fallback: exact match
	return clientIP == s.officeIP
}
