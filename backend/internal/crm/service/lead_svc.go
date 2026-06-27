package service

import (
	"context"
	"errors"

	"github.com/spacesioberyl/system-v1/internal/crm/dto"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
	"github.com/spacesioberyl/system-v1/internal/crm/repository"
	"github.com/spacesioberyl/system-v1/internal/logger"
)

type LeadService struct {
	repo         *repository.LeadRepository
	followUpRepo *repository.FollowUpRepository
}

func NewLeadService(repo *repository.LeadRepository, followUpRepo *repository.FollowUpRepository) *LeadService {
	return &LeadService{repo: repo, followUpRepo: followUpRepo}
}

// validLeadStatuses defines the state machine for leads
var validLeadStatuses = map[string]bool{
	"new": true, "first_call": true, "pdf_sent": true, "sample_sent": true,
	"site_visit": true, "negotiation": true, "finalized": true, "lost": true,
}

func (s *LeadService) Create(ctx context.Context, req dto.CreateLeadRequest) (*model.Lead, error) {
	if req.ClientName == "" || req.ClientPhone == "" {
		return nil, errors.New("client_name and client_phone are required")
	}

	lead := &model.Lead{
		ClientName:  req.ClientName,
		ClientPhone: req.ClientPhone,
	}
	if req.ClientEmail != "" {
		lead.ClientEmail = &req.ClientEmail
	}
	if req.Source != "" {
		lead.Source = &req.Source
	}
	return s.repo.Create(ctx, lead)
}

func (s *LeadService) List(ctx context.Context, status string, assignedTo int) ([]*model.Lead, error) {
	return s.repo.List(ctx, status, assignedTo)
}

func (s *LeadService) GetByID(ctx context.Context, id int) (*model.Lead, error) {
	return s.repo.GetByID(ctx, id)
}

func (s *LeadService) UpdateStatus(ctx context.Context, leadID int, req dto.UpdateLeadStatusRequest) error {
	if !validLeadStatuses[req.Status] {
		return errors.New("invalid status")
	}
	if req.Status == "lost" && req.LostReason == "" {
		return errors.New("lost_reason is required when marking a lead as lost")
	}

	var lostReason *string
	if req.LostReason != "" {
		lostReason = &req.LostReason
	}
	
	if err := s.repo.UpdateStatus(ctx, leadID, req.Status, lostReason); err != nil {
		return err
	}

	if req.Status == "lost" {
		if err := s.followUpRepo.CancelPendingForLead(ctx, leadID); err != nil {
			logger.Log.Error("Failed to cancel pending follow-ups for lost lead", "lead_id", leadID, "error", err)
		}
	}

	return nil
}

func (s *LeadService) Assign(ctx context.Context, leadID, assignedTo int) error {
	return s.repo.Assign(ctx, leadID, assignedTo)
}
