package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/hr/model"
)

type AttendanceRepository struct {
	db *pgxpool.Pool
}

func NewAttendanceRepository(db *pgxpool.Pool) *AttendanceRepository {
	return &AttendanceRepository{db: db}
}

// CheckIn creates or updates today's attendance record with a check-in time
func (r *AttendanceRepository) CheckIn(ctx context.Context, userID int, ipAddress string, isOfficeWifi bool, isOverride bool, overrideReason string) (*model.Attendance, error) {
	status := "present"
	var overrideStatus *string
	var reason *string

	if isOverride {
		status = "pending_override"
		pending := "pending"
		overrideStatus = &pending
		reason = &overrideReason
	}

	query := `
		INSERT INTO attendances (user_id, date, check_in_time, status, ip_address, is_office_wifi, override_reason, override_status)
		VALUES ($1, CURRENT_DATE, NOW(), $2, $3, $4, $5, $6)
		ON CONFLICT (user_id, date) DO NOTHING
		RETURNING id, user_id, date, check_in_time, check_out_time, status, ip_address, is_office_wifi,
		          override_reason, override_status, override_rejected_reason, reviewed_by, created_at, updated_at
	`

	var att model.Attendance
	err := r.db.QueryRow(ctx, query, userID, status, ipAddress, isOfficeWifi, reason, overrideStatus).Scan(
		&att.ID, &att.UserID, &att.Date, &att.CheckInTime, &att.CheckOutTime,
		&att.Status, &att.IPAddress, &att.IsOfficeWifi,
		&att.OverrideReason, &att.OverrideStatus, &att.OverrideRejectedReason,
		&att.ReviewedBy, &att.CreatedAt, &att.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("already checked in today")
		}
		return nil, err
	}
	return &att, nil
}

// CheckOut records the check-out time for today's attendance
func (r *AttendanceRepository) CheckOut(ctx context.Context, userID int) (*model.Attendance, error) {
	query := `
		UPDATE attendances 
		SET check_out_time = NOW(), updated_at = CURRENT_TIMESTAMP
		WHERE user_id = $1 AND date = CURRENT_DATE AND check_in_time IS NOT NULL
		RETURNING id, user_id, date, check_in_time, check_out_time, status, ip_address, is_office_wifi,
		          override_reason, override_status, override_rejected_reason, reviewed_by, created_at, updated_at
	`

	var att model.Attendance
	err := r.db.QueryRow(ctx, query, userID).Scan(
		&att.ID, &att.UserID, &att.Date, &att.CheckInTime, &att.CheckOutTime,
		&att.Status, &att.IPAddress, &att.IsOfficeWifi,
		&att.OverrideReason, &att.OverrideStatus, &att.OverrideRejectedReason,
		&att.ReviewedBy, &att.CreatedAt, &att.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("no check-in found for today")
		}
		return nil, err
	}
	return &att, nil
}

// GetMyAttendance returns the logged-in user's attendance history with optional date filters
func (r *AttendanceRepository) GetMyAttendance(ctx context.Context, userID int, startDate, endDate string) ([]*model.Attendance, error) {
	query := `
		SELECT id, user_id, date, check_in_time, check_out_time, status, ip_address, is_office_wifi,
		       override_reason, override_status, override_rejected_reason, reviewed_by, created_at, updated_at
		FROM attendances WHERE user_id = $1
	`
	args := []interface{}{userID}
	argIdx := 2

	if startDate != "" {
		query += ` AND date >= $` + itoa(argIdx)
		args = append(args, startDate)
		argIdx++
	}
	if endDate != "" {
		query += ` AND date <= $` + itoa(argIdx)
		args = append(args, endDate)
		argIdx++
	}
	query += ` ORDER BY date DESC`

	return r.scanAttendances(ctx, query, args...)
}

// ListAll returns all attendance records with optional date filter (Admin view)
func (r *AttendanceRepository) ListAll(ctx context.Context, date string) ([]*model.Attendance, error) {
	query := `
		SELECT id, user_id, date, check_in_time, check_out_time, status, ip_address, is_office_wifi,
		       override_reason, override_status, override_rejected_reason, reviewed_by, created_at, updated_at
		FROM attendances
	`
	var args []interface{}

	if date != "" {
		query += ` WHERE date = $1`
		args = append(args, date)
	}
	query += ` ORDER BY date DESC, user_id ASC`

	return r.scanAttendances(ctx, query, args...)
}

// ListPendingOverrides returns attendance records that need admin approval
func (r *AttendanceRepository) ListPendingOverrides(ctx context.Context) ([]*model.Attendance, error) {
	query := `
		SELECT id, user_id, date, check_in_time, check_out_time, status, ip_address, is_office_wifi,
		       override_reason, override_status, override_rejected_reason, reviewed_by, created_at, updated_at
		FROM attendances
		WHERE override_status = 'pending'
		ORDER BY created_at ASC
	`
	return r.scanAttendances(ctx, query)
}

// ResolveOverride approves or rejects a pending override request
func (r *AttendanceRepository) ResolveOverride(ctx context.Context, attendanceID, reviewerID int, status, rejectedReason string) error {
	newStatus := "off_site" // If approved, mark as off_site
	if status == "rejected" {
		newStatus = "absent"
	}

	var rejReason *string
	if rejectedReason != "" {
		rejReason = &rejectedReason
	}

	now := time.Now()
	query := `
		UPDATE attendances
		SET override_status = $1, override_rejected_reason = $2, reviewed_by = $3, 
		    status = $4, updated_at = $5
		WHERE id = $6 AND override_status = 'pending'
	`
	tag, err := r.db.Exec(ctx, query, status, rejReason, reviewerID, newStatus, now, attendanceID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("override not found or already resolved")
	}
	return nil
}

// scanAttendances is a DRY helper for scanning attendance rows
func (r *AttendanceRepository) scanAttendances(ctx context.Context, query string, args ...interface{}) ([]*model.Attendance, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*model.Attendance
	for rows.Next() {
		var att model.Attendance
		err := rows.Scan(
			&att.ID, &att.UserID, &att.Date, &att.CheckInTime, &att.CheckOutTime,
			&att.Status, &att.IPAddress, &att.IsOfficeWifi,
			&att.OverrideReason, &att.OverrideStatus, &att.OverrideRejectedReason,
			&att.ReviewedBy, &att.CreatedAt, &att.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		result = append(result, &att)
	}
	return result, rows.Err()
}

// itoa is a tiny helper to avoid importing strconv just for int->string
func itoa(i int) string {
	return string(rune('0' + i))
}
