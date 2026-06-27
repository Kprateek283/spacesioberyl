package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/crm/model"
)

type ComplaintRepository struct {
	db *pgxpool.Pool
}

func NewComplaintRepository(db *pgxpool.Pool) *ComplaintRepository {
	return &ComplaintRepository{db: db}
}

const complaintColumns = `id, created_by, assigned_to, title, description, status, priority,
	lead_id, order_id, client_name, client_phone, escalated_at, resolved_at, created_at, updated_at`

func scanComplaint(row pgx.Row) (*model.ClientComplaint, error) {
	var c model.ClientComplaint
	err := row.Scan(
		&c.ID, &c.CreatedBy, &c.AssignedTo, &c.Title, &c.Description,
		&c.Status, &c.Priority, &c.LeadID, &c.OrderID, &c.ClientName, &c.ClientPhone,
		&c.EscalatedAt, &c.ResolvedAt, &c.CreatedAt, &c.UpdatedAt,
	)
	return &c, err
}

// Create inserts a new client complaint
func (r *ComplaintRepository) Create(ctx context.Context, c *model.ClientComplaint) (*model.ClientComplaint, error) {
	query := `
		INSERT INTO client_complaints (created_by, title, description, priority, lead_id, order_id, client_name, client_phone)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		RETURNING ` + complaintColumns

	result, err := scanComplaint(r.db.QueryRow(ctx, query,
		c.CreatedBy, c.Title, c.Description, c.Priority,
		c.LeadID, c.OrderID, c.ClientName, c.ClientPhone,
	))
	if err != nil {
		return nil, err
	}
	return result, nil
}

// List returns client complaints with optional filters
func (r *ComplaintRepository) List(ctx context.Context, status string, assignedTo, createdBy int) ([]*model.ClientComplaint, error) {
	query := `SELECT ` + complaintColumns + ` FROM client_complaints WHERE 1=1`
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
	if createdBy > 0 {
		query += fmt.Sprintf(" AND created_by = $%d", argIdx)
		args = append(args, createdBy)
		argIdx++
	}
	query += " ORDER BY created_at DESC"

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var complaints []*model.ClientComplaint
	for rows.Next() {
		var c model.ClientComplaint
		err := rows.Scan(
			&c.ID, &c.CreatedBy, &c.AssignedTo, &c.Title, &c.Description,
			&c.Status, &c.Priority, &c.LeadID, &c.OrderID, &c.ClientName, &c.ClientPhone,
			&c.EscalatedAt, &c.ResolvedAt, &c.CreatedAt, &c.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		complaints = append(complaints, &c)
	}
	return complaints, rows.Err()
}

// GetByID fetches a single complaint by ID
func (r *ComplaintRepository) GetByID(ctx context.Context, id int) (*model.ClientComplaint, error) {
	query := `SELECT ` + complaintColumns + ` FROM client_complaints WHERE id = $1`
	result, err := scanComplaint(r.db.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("complaint not found")
		}
		return nil, err
	}
	return result, nil
}

// Assign sets the assigned_to field for a complaint
func (r *ComplaintRepository) Assign(ctx context.Context, complaintID, assignedTo int) error {
	query := `UPDATE client_complaints SET assigned_to = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	tag, err := r.db.Exec(ctx, query, assignedTo, complaintID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("complaint not found")
	}
	return nil
}

// UpdateStatus changes the status of a complaint
func (r *ComplaintRepository) UpdateStatus(ctx context.Context, complaintID int, status string) error {
	query := `UPDATE client_complaints SET status = $1, updated_at = CURRENT_TIMESTAMP`

	if status == "resolved" {
		query += ", resolved_at = $3"
	}
	if status == "escalated" {
		query += ", escalated_at = $3"
	}

	query += ` WHERE id = $2`

	var err error
	if status == "resolved" || status == "escalated" {
		_, err = r.db.Exec(ctx, query, status, complaintID, time.Now())
	} else {
		_, err = r.db.Exec(ctx, query, status, complaintID)
	}
	return err
}

// EscalateOld marks complaints that are unresolved past a threshold as 'escalated'.
// Used by the background worker/cron job.
func (r *ComplaintRepository) EscalateOld(ctx context.Context, thresholdHours int) (int64, error) {
	query := `
		UPDATE client_complaints
		SET status = 'escalated', escalated_at = NOW(), updated_at = CURRENT_TIMESTAMP
		WHERE status NOT IN ('resolved', 'escalated')
		  AND created_at < NOW() - ($1 || ' hours')::INTERVAL
	`
	tag, err := r.db.Exec(ctx, query, fmt.Sprintf("%d", thresholdHours))
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
