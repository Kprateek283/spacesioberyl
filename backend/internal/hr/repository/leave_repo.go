package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/hr/model"
)

type LeaveRepository struct {
	db *pgxpool.Pool
}

func NewLeaveRepository(db *pgxpool.Pool) *LeaveRepository {
	return &LeaveRepository{db: db}
}

const leaveColumns = `id, user_id, leave_type, start_date, end_date, reason, status,
	approved_by, admin_remarks, created_at, updated_at`

func scanLeave(row pgx.Row) (*model.Leave, error) {
	var l model.Leave
	err := row.Scan(
		&l.ID, &l.UserID, &l.LeaveType, &l.StartDate, &l.EndDate,
		&l.Reason, &l.Status, &l.ApprovedBy, &l.AdminRemarks,
		&l.CreatedAt, &l.UpdatedAt,
	)
	return &l, err
}

// Create inserts a new leave request
func (r *LeaveRepository) Create(ctx context.Context, l *model.Leave) (*model.Leave, error) {
	query := `
		INSERT INTO hr_leaves (user_id, leave_type, start_date, end_date, reason)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING ` + leaveColumns

	result, err := scanLeave(r.db.QueryRow(ctx, query,
		l.UserID, l.LeaveType, l.StartDate, l.EndDate, l.Reason,
	))
	if err != nil {
		return nil, err
	}
	return result, nil
}

// ListByUser returns all leave records for a specific user
func (r *LeaveRepository) ListByUser(ctx context.Context, userID int) ([]*model.Leave, error) {
	query := `SELECT ` + leaveColumns + ` FROM hr_leaves WHERE user_id = $1 ORDER BY created_at DESC`
	return r.queryLeaves(ctx, query, userID)
}

// ListAll returns all leave records, optionally filtered by status
func (r *LeaveRepository) ListAll(ctx context.Context, status string) ([]*model.Leave, error) {
	query := `SELECT ` + leaveColumns + ` FROM hr_leaves WHERE 1=1`
	args := []interface{}{}
	argIdx := 1

	if status != "" {
		query += fmt.Sprintf(" AND status = $%d", argIdx)
		args = append(args, status)
	}
	query += " ORDER BY created_at DESC"

	return r.queryLeaves(ctx, query, args...)
}

// GetByID fetches a single leave by ID
func (r *LeaveRepository) GetByID(ctx context.Context, id int) (*model.Leave, error) {
	query := `SELECT ` + leaveColumns + ` FROM hr_leaves WHERE id = $1`
	result, err := scanLeave(r.db.QueryRow(ctx, query, id))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("leave request not found")
		}
		return nil, err
	}
	return result, nil
}

// UserEdit updates dates/reason of a leave (only if still pending)
func (r *LeaveRepository) UserEdit(ctx context.Context, id int, startDate, endDate *time.Time, reason string) error {
	query := `UPDATE hr_leaves SET updated_at = CURRENT_TIMESTAMP`
	args := []interface{}{}
	argIdx := 1

	if startDate != nil {
		query += fmt.Sprintf(", start_date = $%d", argIdx)
		args = append(args, *startDate)
		argIdx++
	}
	if endDate != nil {
		query += fmt.Sprintf(", end_date = $%d", argIdx)
		args = append(args, *endDate)
		argIdx++
	}
	if reason != "" {
		query += fmt.Sprintf(", reason = $%d", argIdx)
		args = append(args, reason)
		argIdx++
	}

	query += fmt.Sprintf(" WHERE id = $%d AND status = 'pending'", argIdx)
	args = append(args, id)

	tag, err := r.db.Exec(ctx, query, args...)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("leave not found or cannot be edited (status is not pending)")
	}
	return nil
}

// AdminEdit force-updates leave details (admin can edit at any status)
func (r *LeaveRepository) AdminEdit(ctx context.Context, id int, leaveType string, startDate, endDate *time.Time, reason string) error {
	query := `UPDATE hr_leaves SET updated_at = CURRENT_TIMESTAMP`
	args := []interface{}{}
	argIdx := 1

	if leaveType != "" {
		query += fmt.Sprintf(", leave_type = $%d", argIdx)
		args = append(args, leaveType)
		argIdx++
	}
	if startDate != nil {
		query += fmt.Sprintf(", start_date = $%d", argIdx)
		args = append(args, *startDate)
		argIdx++
	}
	if endDate != nil {
		query += fmt.Sprintf(", end_date = $%d", argIdx)
		args = append(args, *endDate)
		argIdx++
	}
	if reason != "" {
		query += fmt.Sprintf(", reason = $%d", argIdx)
		args = append(args, reason)
		argIdx++
	}

	query += fmt.Sprintf(" WHERE id = $%d", argIdx)
	args = append(args, id)

	tag, err := r.db.Exec(ctx, query, args...)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("leave request not found")
	}
	return nil
}

// UpdateStatus sets status and optionally approved_by + admin_remarks
func (r *LeaveRepository) UpdateStatus(ctx context.Context, id int, status string, approvedBy int, adminRemarks string) error {
	query := `UPDATE hr_leaves SET status = $1, approved_by = $2, updated_at = CURRENT_TIMESTAMP`
	args := []interface{}{status, approvedBy}

	if adminRemarks != "" {
		query += ", admin_remarks = $3 WHERE id = $4"
		args = append(args, adminRemarks, id)
	} else {
		query += " WHERE id = $3"
		args = append(args, id)
	}

	tag, err := r.db.Exec(ctx, query, args...)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("leave request not found")
	}
	return nil
}

// Cancel sets a leave status to 'cancelled'
func (r *LeaveRepository) Cancel(ctx context.Context, id, userID int) error {
	query := `UPDATE hr_leaves SET status = 'cancelled', updated_at = CURRENT_TIMESTAMP
	          WHERE id = $1 AND user_id = $2 AND status = 'pending'`
	tag, err := r.db.Exec(ctx, query, id, userID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("leave not found, not yours, or cannot be cancelled (status is not pending)")
	}
	return nil
}

// queryLeaves is a helper to scan multiple leave rows
func (r *LeaveRepository) queryLeaves(ctx context.Context, query string, args ...interface{}) ([]*model.Leave, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var leaves []*model.Leave
	for rows.Next() {
		var l model.Leave
		err := rows.Scan(
			&l.ID, &l.UserID, &l.LeaveType, &l.StartDate, &l.EndDate,
			&l.Reason, &l.Status, &l.ApprovedBy, &l.AdminRemarks,
			&l.CreatedAt, &l.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		leaves = append(leaves, &l)
	}
	return leaves, rows.Err()
}
