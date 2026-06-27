package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
)

type FollowUpRepository struct {
	db *pgxpool.Pool
}

func NewFollowUpRepository(db *pgxpool.Pool) *FollowUpRepository {
	return &FollowUpRepository{db: db}
}

// Create inserts a new follow-up
func (r *FollowUpRepository) Create(ctx context.Context, f *model.FollowUp) (*model.FollowUp, error) {
	query := `
		INSERT INTO follow_ups (lead_id, created_by, scheduled_for, notes)
		VALUES ($1, $2, $3, $4)
		RETURNING id, lead_id, created_by, scheduled_for, notes, status, completed_at, outcome_notes, created_at
	`
	var result model.FollowUp
	err := r.db.QueryRow(ctx, query, f.LeadID, f.CreatedBy, f.ScheduledFor, f.Notes).Scan(
		&result.ID, &result.LeadID, &result.CreatedBy, &result.ScheduledFor,
		&result.Notes, &result.Status, &result.CompletedAt, &result.OutcomeNotes, &result.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// GetMyQueue returns pending follow-ups for a specific user, ordered by scheduled_for ASC
func (r *FollowUpRepository) GetMyQueue(ctx context.Context, userID int) ([]*model.FollowUp, error) {
	query := `
		SELECT id, lead_id, created_by, scheduled_for, notes, status, completed_at, outcome_notes, created_at
		FROM follow_ups
		WHERE created_by = $1 AND status = 'pending'
		ORDER BY scheduled_for ASC
	`
	return r.scanFollowUps(ctx, query, userID)
}

// Complete marks a follow-up as done with outcome notes
func (r *FollowUpRepository) Complete(ctx context.Context, followUpID int, outcomeNotes string) error {
	now := time.Now()
	query := `
		UPDATE follow_ups SET status = 'completed', completed_at = $1, outcome_notes = $2
		WHERE id = $3 AND status = 'pending'
	`
	tag, err := r.db.Exec(ctx, query, now, outcomeNotes, followUpID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("follow-up not found or already completed")
	}
	return nil
}

// MarkMissed marks follow-ups as 'missed' where scheduled_for is past the threshold.
// Used by the background worker.
func (r *FollowUpRepository) MarkMissed(ctx context.Context, thresholdHours int) (int64, error) {
	query := `
		UPDATE follow_ups
		SET status = 'missed'
		WHERE status = 'pending'
		  AND scheduled_for < NOW() - ($1 || ' hours')::INTERVAL
	`
	tag, err := r.db.Exec(ctx, query, fmt.Sprintf("%d", thresholdHours))
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// CancelPendingForLead marks all pending follow-ups for a lead as 'cancelled'.
func (r *FollowUpRepository) CancelPendingForLead(ctx context.Context, leadID int) error {
	query := `
		UPDATE follow_ups
		SET status = 'cancelled'
		WHERE lead_id = $1 AND status = 'pending'
	`
	_, err := r.db.Exec(ctx, query, leadID)
	return err
}

func (r *FollowUpRepository) scanFollowUps(ctx context.Context, query string, args ...interface{}) ([]*model.FollowUp, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*model.FollowUp
	for rows.Next() {
		var f model.FollowUp
		if err := rows.Scan(
			&f.ID, &f.LeadID, &f.CreatedBy, &f.ScheduledFor,
			&f.Notes, &f.Status, &f.CompletedAt, &f.OutcomeNotes, &f.CreatedAt,
		); err != nil {
			return nil, err
		}
		result = append(result, &f)
	}
	return result, rows.Err()
}
