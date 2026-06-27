package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/spacesioberyl/system-v1/internal/broker"
	"github.com/spacesioberyl/system-v1/internal/execution/dto"
	"github.com/spacesioberyl/system-v1/internal/execution/model"
	"github.com/spacesioberyl/system-v1/internal/execution/repository"
	"github.com/spacesioberyl/system-v1/internal/middleware"
)

type ExecutionHandler struct {
	repo *repository.ExecutionRepository
}

func NewExecutionHandler(repo *repository.ExecutionRepository) *ExecutionHandler {
	return &ExecutionHandler{repo: repo}
}

func sendExecError(w http.ResponseWriter, status int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(dto.BasicResponse{Error: msg})
}

// =====================================================
// INSTALLER HANDLERS
// =====================================================

func (h *ExecutionHandler) CreateInstaller(w http.ResponseWriter, r *http.Request) {
	var req dto.CreateInstallerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendExecError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	inst := &model.Installer{Name: req.Name, Phone: req.Phone}
	if req.ExpertiseArea != "" {
		inst.ExpertiseArea = &req.ExpertiseArea
	}
	if req.StandardRate > 0 {
		inst.StandardRate = &req.StandardRate
	}
	if req.PreferredPaymentMode != "" {
		inst.PreferredPaymentMode = &req.PreferredPaymentMode
	}

	result, err := h.repo.CreateInstaller(r.Context(), inst)
	if err != nil {
		sendExecError(w, http.StatusInternalServerError, "Failed to create installer")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(result)
}

func (h *ExecutionHandler) ListInstallers(w http.ResponseWriter, r *http.Request) {
	installers, err := h.repo.ListInstallers(r.Context())
	if err != nil {
		sendExecError(w, http.StatusInternalServerError, "Failed to fetch installers")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(installers)
}

// =====================================================
// INSTALLATION JOB HANDLERS
// =====================================================

func (h *ExecutionHandler) ListJobs(w http.ResponseWriter, r *http.Request) {
	jobs, err := h.repo.ListJobs(r.Context())
	if err != nil {
		sendExecError(w, http.StatusInternalServerError, "Failed to fetch jobs")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(jobs)
}

func (h *ExecutionHandler) GetMyJobs(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendExecError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	jobs, err := h.repo.GetMyJobs(r.Context(), claims.UserID)
	if err != nil {
		sendExecError(w, http.StatusInternalServerError, "Failed to fetch jobs")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(jobs)
}

func (h *ExecutionHandler) CreateInstallation(w http.ResponseWriter, r *http.Request) {
	orderID, _ := strconv.Atoi(chi.URLParam(r, "id"))
	var req dto.CreateInstallationRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendExecError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	result, err := h.repo.CreateInstallation(r.Context(), orderID, req.TechnicalManagerID)
	if err != nil {
		sendExecError(w, http.StatusInternalServerError, "Failed to create installation")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(result)
}

func (h *ExecutionHandler) AssignInstaller(w http.ResponseWriter, r *http.Request) {
	jobID, _ := strconv.Atoi(chi.URLParam(r, "id"))
	var req dto.AssignInstallerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendExecError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if err := h.repo.AssignInstaller(r.Context(), jobID, req.InstallerID, req.AgreedInstallerPrice, req.EstimatedCompletionDate); err != nil {
		sendExecError(w, http.StatusBadRequest, err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Installer assigned"})
}

// =====================================================
// OFFLINE SYNC HANDLER
// =====================================================

func (h *ExecutionHandler) SyncUpdates(w http.ResponseWriter, r *http.Request) {
	claims, ok := r.Context().Value(middleware.ClaimsKey).(*middleware.TokenClaims)
	if !ok {
		sendExecError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	jobID, _ := strconv.Atoi(chi.URLParam(r, "id"))
	var req dto.BulkSyncUpdatesRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendExecError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	// Convert DTO to repo format
	var updates []struct {
		UpdateTime time.Time
		Notes      *string
		PhotoURL   *string
	}
	for _, u := range req.Updates {
		t, err := time.Parse(time.RFC3339, u.UpdateTime)
		if err != nil {
			sendExecError(w, http.StatusBadRequest, "update_time must be ISO8601/RFC3339 format")
			return
		}
		entry := struct {
			UpdateTime time.Time
			Notes      *string
			PhotoURL   *string
		}{UpdateTime: t}
		if u.Notes != "" {
			entry.Notes = &u.Notes
		}
		if u.PhotoURL != "" {
			entry.PhotoURL = &u.PhotoURL
		}
		updates = append(updates, entry)
	}

	count, err := h.repo.BulkInsertUpdates(r.Context(), jobID, claims.UserID, updates)
	if err != nil {
		sendExecError(w, http.StatusInternalServerError, "Failed to sync updates")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":        "Updates synced successfully",
		"synced_count":   count,
	})
}

func (h *ExecutionHandler) GetUpdates(w http.ResponseWriter, r *http.Request) {
	jobID, _ := strconv.Atoi(chi.URLParam(r, "id"))
	updates, err := h.repo.GetUpdates(r.Context(), jobID)
	if err != nil {
		sendExecError(w, http.StatusInternalServerError, "Failed to fetch updates")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(updates)
}

// =====================================================
// FINANCIAL LOCK (Signoff)
// =====================================================

func (h *ExecutionHandler) Signoff(w http.ResponseWriter, r *http.Request) {
	jobID, _ := strconv.Atoi(chi.URLParam(r, "id"))
	var req dto.SignoffRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		sendExecError(w, http.StatusBadRequest, "Invalid request payload")
		return
	}

	if req.Status != "client_approved" && req.Status != "redo_required" {
		sendExecError(w, http.StatusBadRequest, "status must be 'client_approved' or 'redo_required'")
		return
	}

	if err := h.repo.Signoff(r.Context(), jobID, req.ClientSignoffURL, req.Status, req.ClientFeedback); err != nil {
		sendExecError(w, http.StatusBadRequest, err.Error())
		return
	}

	// Financial Lock: Publish event so the worker can evaluate payment terms and notify Accounts
	if req.Status == "client_approved" {
		installation, err := h.repo.GetByID(r.Context(), jobID)
		if err == nil {
			_ = broker.PublishEvent(r.Context(), broker.QueueInstallationSignoff, map[string]interface{}{
				"installation_id": installation.ID,
				"order_id":        installation.OrderID,
			})
		}
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(dto.BasicResponse{Message: "Signoff recorded"})
}
