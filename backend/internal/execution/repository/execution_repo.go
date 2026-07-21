package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/execution/model"
)

type ExecutionRepository struct {
	db *pgxpool.Pool
}

func NewExecutionRepository(db *pgxpool.Pool) *ExecutionRepository {
	return &ExecutionRepository{db: db}
}

// =====================================================
// INSTALLER OPERATIONS
// =====================================================

func (r *ExecutionRepository) CreateInstaller(ctx context.Context, inst *model.Installer) (*model.Installer, error) {
	query := `
		INSERT INTO installers (name, phone, expertise_area, standard_rate, preferred_payment_mode)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, name, phone, expertise_area, standard_rate, preferred_payment_mode, is_active, created_at
	`
	var result model.Installer
	err := r.db.QueryRow(ctx, query, inst.Name, inst.Phone, inst.ExpertiseArea, inst.StandardRate, inst.PreferredPaymentMode).Scan(
		&result.ID, &result.Name, &result.Phone, &result.ExpertiseArea,
		&result.StandardRate, &result.PreferredPaymentMode, &result.IsActive, &result.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &result, nil
}

func (r *ExecutionRepository) ListInstallers(ctx context.Context) ([]*model.Installer, error) {
	query := `
		SELECT id, name, phone, expertise_area, standard_rate, preferred_payment_mode, is_active, created_at
		FROM installers WHERE is_active = true ORDER BY name ASC
	`
	rows, err := r.db.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var installers []*model.Installer
	for rows.Next() {
		var i model.Installer
		if err := rows.Scan(&i.ID, &i.Name, &i.Phone, &i.ExpertiseArea, &i.StandardRate, &i.PreferredPaymentMode, &i.IsActive, &i.CreatedAt); err != nil {
			return nil, err
		}
		installers = append(installers, &i)
	}
	return installers, rows.Err()
}

// =====================================================
// INSTALLATION JOB OPERATIONS
// =====================================================

func (r *ExecutionRepository) CreateInstallation(ctx context.Context, orderID, technicalManagerID int) (*model.Installation, error) {
	query := `
		INSERT INTO installations (order_id, technical_manager_id, start_date)
		VALUES ($1, $2, CURRENT_DATE)
		RETURNING id, order_id, technical_manager_id, installer_id, agreed_installer_price, start_date,
		          estimated_completion_date, status, installer_job_status, installer_advance_amount,
		          installer_final_amount, client_signoff_url, client_feedback, created_at, updated_at
	`
	var inst model.Installation
	err := r.db.QueryRow(ctx, query, orderID, technicalManagerID).Scan(
		&inst.ID, &inst.OrderID, &inst.TechnicalManagerID, &inst.InstallerID,
		&inst.AgreedInstallerPrice, &inst.StartDate, &inst.EstimatedCompletionDate,
		&inst.Status, &inst.InstallerJobStatus, &inst.InstallerAdvanceAmount,
		&inst.InstallerFinalAmount, &inst.ClientSignoffURL, &inst.ClientFeedback, &inst.CreatedAt, &inst.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &inst, nil
}

func (r *ExecutionRepository) ListJobs(ctx context.Context) ([]*model.Installation, error) {
	query := `
		SELECT id, order_id, technical_manager_id, installer_id, agreed_installer_price, start_date,
		       estimated_completion_date, status, installer_job_status, installer_advance_amount,
		       installer_final_amount, client_signoff_url, client_feedback, created_at, updated_at
		FROM installations ORDER BY created_at DESC
	`
	return r.scanInstallations(ctx, query)
}

func (r *ExecutionRepository) GetMyJobs(ctx context.Context, techManagerID int) ([]*model.Installation, error) {
	query := `
		SELECT id, order_id, technical_manager_id, installer_id, agreed_installer_price, start_date,
		       estimated_completion_date, status, installer_job_status, installer_advance_amount,
		       installer_final_amount, client_signoff_url, client_feedback, created_at, updated_at
		FROM installations WHERE technical_manager_id = $1 ORDER BY created_at DESC
	`
	return r.scanInstallations(ctx, query, techManagerID)
}

func (r *ExecutionRepository) GetByID(ctx context.Context, id int) (*model.Installation, error) {
	query := `
		SELECT id, order_id, technical_manager_id, installer_id, agreed_installer_price, start_date,
		       estimated_completion_date, status, installer_job_status, installer_advance_amount,
		       installer_final_amount, client_signoff_url, client_feedback, created_at, updated_at
		FROM installations WHERE id = $1
	`
	var inst model.Installation
	err := r.db.QueryRow(ctx, query, id).Scan(
		&inst.ID, &inst.OrderID, &inst.TechnicalManagerID, &inst.InstallerID,
		&inst.AgreedInstallerPrice, &inst.StartDate, &inst.EstimatedCompletionDate,
		&inst.Status, &inst.InstallerJobStatus, &inst.InstallerAdvanceAmount,
		&inst.InstallerFinalAmount, &inst.ClientSignoffURL, &inst.ClientFeedback, &inst.CreatedAt, &inst.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("installation not found")
		}
		return nil, err
	}
	return &inst, nil
}

func (r *ExecutionRepository) AssignInstaller(ctx context.Context, jobID, installerID int, price int64, estimatedDate string) error {
	query := `
		UPDATE installations SET installer_id = $1, agreed_installer_price = $2, estimated_completion_date = $3,
		       status = 'in_progress', updated_at = CURRENT_TIMESTAMP
		WHERE id = $4
	`
	var dateArg interface{} = nil
	if estimatedDate != "" {
		dateArg = estimatedDate
	}
	tag, err := r.db.Exec(ctx, query, installerID, price, dateArg, jobID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("installation not found")
	}
	return nil
}

func (r *ExecutionRepository) Signoff(ctx context.Context, jobID int, signoffURL, status, feedback string) error {
	query := `
		UPDATE installations SET status = $1, client_signoff_url = $2, client_feedback = $3, 
		       updated_at = CURRENT_TIMESTAMP
		WHERE id = $4
	`
	tag, err := r.db.Exec(ctx, query, status, signoffURL, feedback, jobID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("installation not found")
	}
	return nil
}

// =====================================================
// INSTALLATION UPDATES (Offline Sync)
// =====================================================

// BulkInsertUpdates inserts an array of offline-synced updates.
// Uses the client's update_time (trust device clock) and server's NOW() for created_at.
func (r *ExecutionRepository) BulkInsertUpdates(ctx context.Context, installationID, loggedBy int, updates []struct {
	UpdateTime time.Time
	Notes      *string
	PhotoURL   *string
}) (int, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	inserted := 0
	for _, u := range updates {
		query := `
			INSERT INTO installation_updates (installation_id, logged_by, update_time, notes, photo_url)
			VALUES ($1, $2, $3, $4, $5)
		`
		_, err := tx.Exec(ctx, query, installationID, loggedBy, u.UpdateTime, u.Notes, u.PhotoURL)
		if err != nil {
			return 0, err
		}
		inserted++
	}

	if err := tx.Commit(ctx); err != nil {
		return 0, err
	}
	return inserted, nil
}

func (r *ExecutionRepository) GetUpdates(ctx context.Context, installationID int) ([]*model.InstallationUpdate, error) {
	query := `
		SELECT id, installation_id, logged_by, update_time, notes, photo_url, created_at
		FROM installation_updates WHERE installation_id = $1 ORDER BY update_time ASC
	`
	rows, err := r.db.Query(ctx, query, installationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var updates []*model.InstallationUpdate
	for rows.Next() {
		var u model.InstallationUpdate
		if err := rows.Scan(&u.ID, &u.InstallationID, &u.LoggedBy, &u.UpdateTime, &u.Notes, &u.PhotoURL, &u.CreatedAt); err != nil {
			return nil, err
		}
		updates = append(updates, &u)
	}
	return updates, rows.Err()
}

func (r *ExecutionRepository) scanInstallations(ctx context.Context, query string, args ...interface{}) ([]*model.Installation, error) {
	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var installations []*model.Installation
	for rows.Next() {
		var inst model.Installation
		if err := rows.Scan(
			&inst.ID, &inst.OrderID, &inst.TechnicalManagerID, &inst.InstallerID,
			&inst.AgreedInstallerPrice, &inst.StartDate, &inst.EstimatedCompletionDate,
			&inst.Status, &inst.InstallerJobStatus, &inst.InstallerAdvanceAmount,
			&inst.InstallerFinalAmount, &inst.ClientSignoffURL, &inst.ClientFeedback, &inst.CreatedAt, &inst.UpdatedAt,
		); err != nil {
			return nil, err
		}
		installations = append(installations, &inst)
	}
	return installations, rows.Err()
}

// GetClientInfoByInstallationID joins installations → orders → leads to look up the client's phone and name.
// Returns the phone and client_name as stored in leads. Used for WhatsApp notifications.
func (r *ExecutionRepository) GetClientInfoByInstallationID(ctx context.Context, installationID int) (phone, clientName string, err error) {
	query := `
		SELECT l.client_phone, l.client_name
		FROM installations i
		JOIN orders o ON i.order_id = o.id
		JOIN leads l ON o.lead_id = l.id
		WHERE i.id = $1
	`
	err = r.db.QueryRow(ctx, query, installationID).Scan(&phone, &clientName)
	return
}

