package service

import (
	"context"
	"errors"

	"github.com/spacesioberyl/system-v1/internal/execution/dto"
	"github.com/spacesioberyl/system-v1/internal/execution/model"
	"github.com/spacesioberyl/system-v1/internal/execution/repository"
)

// validInstallerJobStatuses defines the complete state machine for the installer lifecycle
var validInstallerJobStatuses = map[string]bool{
	"assigned": true, "accepted": true, "advance_disbursed": true,
	"en_route": true, "on_site": true, "in_progress": true,
	"completed_pending_signoff": true, "client_approved": true, "payment_discharged": true,
}

type ContractorService struct {
	repo *repository.ContractorRepository
}

func NewContractorService(repo *repository.ContractorRepository) *ContractorService {
	return &ContractorService{repo: repo}
}

// UpdateInstallerJobStatus validates the status and updates it
func (s *ContractorService) UpdateInstallerJobStatus(ctx context.Context, jobID int, req dto.UpdateInstallerJobStatusRequest) error {
	if !validInstallerJobStatuses[req.Status] {
		return errors.New("invalid installer_job_status; must be one of: assigned, accepted, advance_disbursed, en_route, on_site, in_progress, completed_pending_signoff, client_approved, payment_discharged")
	}
	return s.repo.UpdateInstallerJobStatus(ctx, jobID, req.Status)
}

// CheckIn enforces the Verification Enforcement rule: verification_notes MUST be populated.
// Then records the daily attendance log tied to the logged-in manager (verified_by).
func (s *ContractorService) CheckIn(ctx context.Context, jobID, verifiedBy int, req dto.InstallerCheckInRequest) (*model.InstallerDailyLog, error) {
	// BUSINESS RULE: Verification Enforcement — notes cannot be empty
	if req.VerificationNotes == "" {
		return nil, errors.New("verification_notes is required — describe how you confirmed contractor presence (e.g., 'Called at 9:30 AM, confirmed on site')")
	}

	// Look up the installation to get the installer_id
	inst, err := s.repo.GetInstallation(ctx, jobID)
	if err != nil {
		return nil, err
	}
	if inst.InstallerID == nil {
		return nil, errors.New("no installer assigned to this job — assign an installer first")
	}

	var photoURL *string
	if req.ProofPhotoURL != "" {
		photoURL = &req.ProofPhotoURL
	}

	return s.repo.CheckIn(ctx, jobID, *inst.InstallerID, verifiedBy, req.VerificationNotes, photoURL)
}

// CheckOut records the departure time for today
func (s *ContractorService) CheckOut(ctx context.Context, jobID int) (*model.InstallerDailyLog, error) {
	inst, err := s.repo.GetInstallation(ctx, jobID)
	if err != nil {
		return nil, err
	}
	if inst.InstallerID == nil {
		return nil, errors.New("no installer assigned to this job")
	}
	return s.repo.CheckOut(ctx, jobID, *inst.InstallerID)
}

// RecordPayment enforces the Advance Block and Final Discharge Lock business rules,
// then records the payment and updates running totals.
func (s *ContractorService) RecordPayment(ctx context.Context, jobID, processedBy int, req dto.RecordInstallerPaymentRequest) (*model.InstallerPayment, error) {
	if req.Amount <= 0 {
		return nil, errors.New("amount must be greater than zero")
	}
	if req.PaymentType != "advance" && req.PaymentType != "final_discharge" {
		return nil, errors.New("payment_type must be 'advance' or 'final_discharge'")
	}
	validModes := map[string]bool{"cash": true, "bank_transfer": true, "upi": true}
	if !validModes[req.PaymentMode] {
		return nil, errors.New("payment_mode must be 'cash', 'bank_transfer', or 'upi'")
	}

	// Fetch current installation state for business rule checks
	inst, err := s.repo.GetInstallation(ctx, jobID)
	if err != nil {
		return nil, err
	}
	if inst.InstallerID == nil {
		return nil, errors.New("no installer assigned to this job — assign an installer first")
	}

	// BUSINESS RULE 1: The Advance Block
	// Advance payment requires installer_job_status >= 'accepted'
	if req.PaymentType == "advance" {
		advanceAllowed := map[string]bool{
			"accepted": true, "advance_disbursed": true, "en_route": true, "on_site": true,
			"in_progress": true, "completed_pending_signoff": true, "client_approved": true, "payment_discharged": true,
		}
		if !advanceAllowed[inst.InstallerJobStatus] {
			return nil, errors.New("advance payment blocked — installer_job_status must be at least 'accepted' (current: " + inst.InstallerJobStatus + ")")
		}
	}

	// BUSINESS RULE 3: The Final Discharge Lock (CRITICAL)
	// Final discharge BLOCKED unless installations.status == 'client_approved'
	if req.PaymentType == "final_discharge" {
		if inst.Status != "client_approved" {
			return nil, errors.New("final discharge BLOCKED — installation must have client_approved status before final payout (current: " + inst.Status + ")")
		}
	}

	var txRef *string
	if req.TransactionReference != "" {
		txRef = &req.TransactionReference
	}

	payment := &model.InstallerPayment{
		InstallationID:       jobID,
		InstallerID:          *inst.InstallerID,
		ProcessedBy:          processedBy,
		Amount:               req.Amount,
		PaymentType:          req.PaymentType,
		PaymentMode:          req.PaymentMode,
		TransactionReference: txRef,
	}

	result, err := s.repo.RecordPayment(ctx, payment)
	if err != nil {
		return nil, err
	}

	// Auto-advance status to 'advance_disbursed' after successful advance payment
	if req.PaymentType == "advance" && inst.InstallerJobStatus == "accepted" {
		_ = s.repo.UpdateInstallerJobStatus(ctx, jobID, "advance_disbursed")
	}

	// Auto-advance status to 'payment_discharged' after final discharge
	if req.PaymentType == "final_discharge" {
		_ = s.repo.UpdateInstallerJobStatus(ctx, jobID, "payment_discharged")
	}

	return result, nil
}

// GetLedger returns the financial summary for a contractor job
func (s *ContractorService) GetLedger(ctx context.Context, jobID int) (*dto.InstallerLedgerResponse, error) {
	agreedPrice, installerID, totalAdvance, totalFinal, err := s.repo.GetLedger(ctx, jobID)
	if err != nil {
		return nil, err
	}

	totalPaid := totalAdvance + totalFinal
	return &dto.InstallerLedgerResponse{
		InstallationID:   jobID,
		InstallerID:      installerID,
		AgreedPrice:      agreedPrice,
		TotalAdvance:     totalAdvance,
		TotalFinal:       totalFinal,
		TotalPaid:        totalPaid,
		RemainingBalance: agreedPrice - totalPaid,
	}, nil
}

// GetClientInfo looks up the client phone and name for WhatsApp notifications
func (s *ContractorService) GetClientInfo(ctx context.Context, jobID int) (phone, clientName string, err error) {
	return s.repo.GetClientInfoByInstallationID(ctx, jobID)
}

