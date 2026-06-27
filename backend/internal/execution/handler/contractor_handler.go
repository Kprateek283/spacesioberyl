package handler

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/execution/dto"
	"github.com/spacesioberyl/system-v1/internal/execution/service"
	"github.com/spacesioberyl/system-v1/internal/logger"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type ContractorHandler struct {
	svc *service.ContractorService
}

func NewContractorHandler(svc *service.ContractorService) *ContractorHandler {
	return &ContractorHandler{svc: svc}
}

func sendContractorError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(dto.BasicResponse{Error: msg})
}

// UpdateInstallerJobStatus maps to PATCH /api/v1/execution/contractors/jobs/:id/status
func (h *ContractorHandler) UpdateInstallerJobStatus(w http.ResponseWriter, r *http.Request) {
	jobID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid job ID")
		return
	}

	var req dto.UpdateInstallerJobStatusRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.svc.UpdateInstallerJobStatus(r.Context(), jobID, req); err != nil {
		sendContractorError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Installer job status updated"})
}

// InstallerCheckIn maps to POST /api/v1/execution/contractors/jobs/:id/check-in
func (h *ContractorHandler) InstallerCheckIn(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendContractorError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	jobID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid job ID")
		return
	}

	var req dto.InstallerCheckInRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	log, err := h.svc.CheckIn(r.Context(), jobID, claims.UserID, req)
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Best-effort WhatsApp notification — installer has checked in on site
	go func() {
		ctx := context.Background()
		phone, clientName, err := h.svc.GetClientInfo(ctx, jobID)
		if err != nil {
			logger.Log.Warn("WhatsApp: failed to look up client info for check-in", "job_id", jobID, "error", err)
			return
		}
		vars := map[string]string{
			"1": clientName,
			"2": "Installer On Site",
			"3": "Our installer has arrived at your location and work will begin shortly.",
		}
		if err := broker.PublishWhatsAppNotification(ctx, phone, "status_update", vars); err != nil {
			logger.Log.Error("WhatsApp: failed to publish check-in notification", "job_id", jobID, "error", err)
		}
	}()

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(log)
}

// InstallerCheckOut maps to POST /api/v1/execution/contractors/jobs/:id/check-out
func (h *ContractorHandler) InstallerCheckOut(w http.ResponseWriter, r *http.Request) {
	jobID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid job ID")
		return
	}

	log, err := h.svc.CheckOut(r.Context(), jobID)
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(log)
}

// RecordPayment maps to POST /api/v1/execution/contractors/jobs/:id/payments
func (h *ContractorHandler) RecordPayment(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendContractorError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	jobID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid job ID")
		return
	}

	var req dto.RecordInstallerPaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	payment, err := h.svc.RecordPayment(r.Context(), jobID, claims.UserID, req)
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(payment)
}

// GetLedger maps to GET /api/v1/execution/contractors/jobs/:id/ledger
func (h *ContractorHandler) GetLedger(w http.ResponseWriter, r *http.Request) {
	jobID, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		sendContractorError(w, http.StatusBadRequest, "Invalid job ID")
		return
	}

	ledger, err := h.svc.GetLedger(r.Context(), jobID)
	if err != nil {
		sendContractorError(w, http.StatusNotFound, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(ledger)
}
