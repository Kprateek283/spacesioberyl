package repository

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spacesioberyl/system-v1/internal/execution/model"
)

type ContractorRepository struct {
	db *pgxpool.Pool
}

func NewContractorRepository(db *pgxpool.Pool) *ContractorRepository {
	return &ContractorRepository{db: db}
}

// UpdateInstallerJobStatus sets the installer_job_status on an installation
func (r *ContractorRepository) UpdateInstallerJobStatus(ctx context.Context, jobID int, status string) error {
	query := `UPDATE installations SET installer_job_status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	tag, err := r.db.Exec(ctx, query, status, jobID)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return errors.New("installation not found")
	}
	return nil
}

// GetInstallation fetches a single installation for business rule checks
func (r *ContractorRepository) GetInstallation(ctx context.Context, jobID int) (*model.Installation, error) {
	query := `
		SELECT id, order_id, technical_manager_id, installer_id, agreed_installer_price, start_date,
		       estimated_completion_date, status, installer_job_status, installer_advance_amount,
		       installer_final_amount, client_signoff_url, client_feedback, created_at, updated_at
		FROM installations WHERE id = $1
	`
	var inst model.Installation
	err := r.db.QueryRow(ctx, query, jobID).Scan(
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

// CheckIn records or updates today's daily verification log (UPSERT on unique constraint)
func (r *ContractorRepository) CheckIn(ctx context.Context, installationID, installerID, verifiedBy int, notes string, photoURL *string) (*model.InstallerDailyLog, error) {
	query := `
		INSERT INTO installer_daily_logs (installation_id, installer_id, date, verified_by, check_in_time, verification_notes, proof_photo_url)
		VALUES ($1, $2, CURRENT_DATE, $3, NOW(), $4, $5)
		ON CONFLICT (installation_id, installer_id, date) DO UPDATE SET
			check_in_time = NOW(),
			verified_by = $3,
			verification_notes = $4,
			proof_photo_url = $5
		RETURNING id, installation_id, installer_id, date, verified_by, check_in_time, verification_notes, proof_photo_url, check_out_time, created_at
	`
	var log model.InstallerDailyLog
	err := r.db.QueryRow(ctx, query, installationID, installerID, verifiedBy, notes, photoURL).Scan(
		&log.ID, &log.InstallationID, &log.InstallerID, &log.Date, &log.VerifiedBy,
		&log.CheckInTime, &log.VerificationNotes, &log.ProofPhotoURL, &log.CheckOutTime, &log.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &log, nil
}

// CheckOut records the check-out time for today's daily log
func (r *ContractorRepository) CheckOut(ctx context.Context, installationID, installerID int) (*model.InstallerDailyLog, error) {
	query := `
		UPDATE installer_daily_logs
		SET check_out_time = NOW()
		WHERE installation_id = $1 AND installer_id = $2 AND date = CURRENT_DATE AND check_in_time IS NOT NULL
		RETURNING id, installation_id, installer_id, date, verified_by, check_in_time, verification_notes, proof_photo_url, check_out_time, created_at
	`
	var log model.InstallerDailyLog
	err := r.db.QueryRow(ctx, query, installationID, installerID).Scan(
		&log.ID, &log.InstallationID, &log.InstallerID, &log.Date, &log.VerifiedBy,
		&log.CheckInTime, &log.VerificationNotes, &log.ProofPhotoURL, &log.CheckOutTime, &log.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("no check-in found for today — check in first")
		}
		return nil, err
	}
	return &log, nil
}

// RecordPayment inserts a payment and updates the installation's advance/final totals
func (r *ContractorRepository) RecordPayment(ctx context.Context, payment *model.InstallerPayment) (*model.InstallerPayment, error) {
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx)

	// 1. Insert the payment record
	insertQuery := `
		INSERT INTO installer_payments (installation_id, installer_id, processed_by, amount, payment_type, payment_mode, transaction_reference)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, installation_id, installer_id, processed_by, amount, payment_type, payment_mode, transaction_reference, paid_at
	`
	var result model.InstallerPayment
	err = tx.QueryRow(ctx, insertQuery,
		payment.InstallationID, payment.InstallerID, payment.ProcessedBy,
		payment.Amount, payment.PaymentType, payment.PaymentMode, payment.TransactionReference,
	).Scan(
		&result.ID, &result.InstallationID, &result.InstallerID, &result.ProcessedBy,
		&result.Amount, &result.PaymentType, &result.PaymentMode, &result.TransactionReference, &result.PaidAt,
	)
	if err != nil {
		return nil, err
	}

	// 2. Update the installation's running totals
	var updateCol string
	switch payment.PaymentType {
	case "advance":
		updateCol = "installer_advance_amount"
	case "final_discharge":
		updateCol = "installer_final_amount"
	}

	updateQuery := `UPDATE installations SET ` + updateCol + ` = ` + updateCol + ` + $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`
	_, err = tx.Exec(ctx, updateQuery, payment.Amount, payment.InstallationID)
	if err != nil {
		return nil, err
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return &result, nil
}

// GetLedger aggregates payments for a given installation and returns a financial summary
func (r *ContractorRepository) GetLedger(ctx context.Context, jobID int) (agreedPrice float64, installerID int, totalAdvance, totalFinal float64, err error) {
	// Get agreed price and installer ID from the installation
	instQuery := `SELECT COALESCE(agreed_installer_price, 0), COALESCE(installer_id, 0) FROM installations WHERE id = $1`
	err = r.db.QueryRow(ctx, instQuery, jobID).Scan(&agreedPrice, &installerID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			err = errors.New("installation not found")
		}
		return
	}

	// Get aggregated payment totals
	payQuery := `
		SELECT 
			COALESCE(SUM(CASE WHEN payment_type = 'advance' THEN amount ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN payment_type = 'final_discharge' THEN amount ELSE 0 END), 0)
		FROM installer_payments WHERE installation_id = $1
	`
	_ = r.db.QueryRow(ctx, payQuery, jobID).Scan(&totalAdvance, &totalFinal)
	return
}

// ignore unused import warning
var _ = time.Now

// GetClientInfoByInstallationID joins installations → orders → leads to look up the client's phone and name.
// Used for WhatsApp notifications on installer check-in events.
func (r *ContractorRepository) GetClientInfoByInstallationID(ctx context.Context, installationID int) (phone, clientName string, err error) {
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

