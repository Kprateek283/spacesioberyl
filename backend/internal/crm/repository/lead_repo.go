package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
)

type LeadRepository struct {
	db *pgxpool.Pool
}

func NewLeadRepository(db *pgxpool.Pool) *LeadRepository {
	return &LeadRepository{db: db}
}

// Create inserts a new lead
func (r *LeadRepository) Create(ctx context.Context, l *model.Lead) (*model.Lead, error) {
	query := `
		INSERT INTO leads (client_name, client_phone, client_email, source, assigned_to)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, client_name, client_phone, client_email, source, assigned_to, status, lost_reason, created_at, updated_at
	`
	var result model.Lead
	err := r.db.QueryRow(ctx, query, l.ClientName, l.ClientPhone, l.ClientEmail, l.Source, l.AssignedTo).Scan(
		&result.ID, &result.ClientName, &result.ClientPhone, &result.ClientEmail,
		&result.Source, &result.AssignedTo, &result.Status, &result.LostReason,
		&result.CreatedAt, &result.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

// List returns leads with optional filters
func (r *LeadRepository) List(ctx context.Context, status string, assignedTo int) ([]*model.Lead, error) {
	query := `
		SELECT id, client_name, client_phone, client_email, source, assigned_to, status, lost_reason, created_at, updated_at
		FROM leads WHERE 1=1
	`
	args := []interface{}{}
	argIdx := 1

	if status != "" {
		query += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, status)
		argIdx++
	}
	if assignedTo > 0 {
		query += fmt.Sprintf(" AND assigned_to = $%d", argIdx)
		args = append(args, assignedTo)
		argIdx++
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var leads []*model.Lead
	for rows.Next() {
		var l model.Lead
		if err := rows.Scan(
			&l.ID, &l.ClientName, &l.ClientPhone, &l.ClientEmail,
			&l.Source, &l.AssignedTo, &l.Status, &l.LostReason,
			&l.CreatedAt, &l.UpdatedAt,
		); err != nil {
			return nil, err
		}
		leads = append(leads, &l)
	}
	return leads, rows.Err()
}

// GetByID fetches a single lead
func (r *LeadRepository) GetByID(ctx context.Context, id int) (*model.Lead, error) {
	query := `
		SELECT id, client_name, client_phone, client_email, source, assigned_to, status, lost_reason, created_at, updated_at
		FROM leads WHERE id = $1
	`
	var l model.Lead
	err := r.db.QueryRow(ctx, query, id).Scan(
		&l.ID, &l.ClientName, &l.ClientPhone, &l.ClientEmail,
		&l.Source, &l.AssignedTo, &l.Status, &l.LostReason,
		&l.CreatedAt, &l.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("lead not found")
		}
		return nil, err
	}
	return &l, nil
}

// UpdateStatus changes a lead's status, optionally setting lost_reason
func (r *LeadRepository) UpdateStatus(ctx context.Context, id int, status string, lostReason *string) error {
	query := `UPDATE leads SET status = $1, lost_reason = $2, updated_at = CURRENT_TIMESTAMP WHERE id = $3`
	tag, err := r.db.Exec(ctx, query, status, lostReason, id)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("lead not found")
	}
	return nil
}

// Assign sets the assigned_to field for a lead
func (r *LeadRepository) Assign(ctx context.Context, leadID, assignedTo int) error {
	query := `UPDATE leads SET assigned_to = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	tag, err := r.db.Exec(ctx, query, assignedTo, leadID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("lead not found")
	}
	return nil
}
