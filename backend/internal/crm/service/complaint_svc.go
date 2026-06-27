package service

import (
	"context"
	"errors"

	"github.com/spacesioberyl/system-v1/internal/crm/dto"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
	"github.com/spacesioberyl/system-v1/internal/crm/repository"
)

type ComplaintService struct {
	repo *repository.ComplaintRepository
}

func NewComplaintService(repo *repository.ComplaintRepository) *ComplaintService {
	return &ComplaintService{repo: repo}
}

// Create inserts a new client complaint. Requires at least lead_id or order_id.
func (s *ComplaintService) Create(ctx context.Context, userID int, req dto.CreateClientComplaintRequest) (*model.ClientComplaint, error) {
	if req.Title == "" || req.Description == "" {
		return nil, errors.New("title and description are required")
	}

	valid := map[string]bool{"low": true, "medium": true, "high": true, "critical": true}
	if !valid[req.Priority] {
		return nil, errors.New("priority must be one of: low, medium, high, critical")
	}

	// At least one client reference is required
	if req.LeadID == nil && req.OrderID == nil && req.ClientName == "" {
		return nil, errors.New("at least one of lead_id, order_id, or client_name is required")
	}

	var clientName, clientPhone *string
	if req.ClientName != "" {
		clientName = &req.ClientName
	}
	if req.ClientPhone != "" {
		clientPhone = &req.ClientPhone
	}

	complaint := &model.ClientComplaint{
		CreatedBy:   userID,
		Title:       req.Title,
		Description: req.Description,
		Priority:    req.Priority,
		LeadID:      req.LeadID,
		OrderID:     req.OrderID,
		ClientName:  clientName,
		ClientPhone: clientPhone,
	}
	return s.repo.Create(ctx, complaint)
}

// List returns complaints with optional filters
func (s *ComplaintService) List(ctx context.Context, status string, assignedTo, createdBy int) ([]*model.ClientComplaint, error) {
	return s.repo.List(ctx, status, assignedTo, createdBy)
}

// GetByID returns a single complaint
func (s *ComplaintService) GetByID(ctx context.Context, id int) (*model.ClientComplaint, error) {
	return s.repo.GetByID(ctx, id)
}

// Assign sets the assignee for a complaint
func (s *ComplaintService) Assign(ctx context.Context, complaintID, assignedTo int) error {
	return s.repo.Assign(ctx, complaintID, assignedTo)
}

// UpdateStatus changes a complaint's status
func (s *ComplaintService) UpdateStatus(ctx context.Context, complaintID int, req dto.UpdateComplaintStatusRequest) error {
	valid := map[string]bool{"open": true, "in_progress": true, "resolved": true, "escalated": true}
	if !valid[req.Status] {
		return errors.New("status must be one of: open, in_progress, resolved, escalated")
	}
	return s.repo.UpdateStatus(ctx, complaintID, req.Status)
}
