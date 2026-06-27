package service

import (
	"context"
	"errors"
	"time"

	"github.com/spacesioberyl/system-v1/internal/crm/dto"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
	"github.com/spacesioberyl/system-v1/internal/crm/repository"
)

type FollowUpService struct {
	repo *repository.FollowUpRepository
}

func NewFollowUpService(repo *repository.FollowUpRepository) *FollowUpService {
	return &FollowUpService{repo: repo}
}

func (s *FollowUpService) Create(ctx context.Context, userID int, req dto.CreateFollowUpRequest) (*model.FollowUp, error) {
	if req.LeadID <= 0 {
		return nil, errors.New("lead_id is required")
	}

	scheduledFor, err := time.Parse(time.RFC3339, req.ScheduledFor)
	if err != nil {
		return nil, errors.New("scheduled_for must be a valid ISO8601/RFC3339 timestamp")
	}

	followUp := &model.FollowUp{
		LeadID:       req.LeadID,
		CreatedBy:    userID,
		ScheduledFor: scheduledFor,
	}
	if req.Notes != "" {
		followUp.Notes = &req.Notes
	}
	return s.repo.Create(ctx, followUp)
}

func (s *FollowUpService) GetMyQueue(ctx context.Context, userID int) ([]*model.FollowUp, error) {
	return s.repo.GetMyQueue(ctx, userID)
}

func (s *FollowUpService) Complete(ctx context.Context, followUpID int, req dto.CompleteFollowUpRequest) error {
	if req.OutcomeNotes == "" {
		return errors.New("outcome_notes is required")
	}
	return s.repo.Complete(ctx, followUpID, req.OutcomeNotes)
}
